--luapower package database library (Cosmin Apreutesei, public domain).
--leverages the many conventions in luapower to extract and aggregate metadata about
--packages, modules, and documentation and perform various consistency checks.
--it also generates and updates the list of packages that is used on luapower.com
--and the table of contents. the entire API is memoized so it can be abused
--without worrying about doing multiple calls on the same arguments.

--NOTE: make sure this is the very first module that you require(),
--otherwise get_dep_list() will not track all dependencies!

--helpers
---------------------------------------------------------------------------

--find dependencies of a module by tracing the `require` calls.

local modules = {} --{module = {dep1 = true, ...}}
local parents = {}
local require_ = require

function require(m)
	modules[m] = modules[m] or {}
	local parent = parents[#parents]
	if parent then
		modules[parent][m] = true
	end
	table.insert(parents, m)
	local ret = require_(m)
	table.remove(parents)
	return ret
end

local function get_deps(m)
	require(m)
	return modules[m]
end

--get a refined and ordered list of dependencies for printing

--standard names to appear in the list before other names
local std = {}
for k in pairs(package.loaded) do
	std[k] = true
end
std.ffi = true
std.jit = true

--built-in libraries, to ignore
local exclude = {string = true, table = true, coroutine = true, package = true, io = true}

local dep_lists = {}

local function get_dep_list(m)
	if dep_lists[m] then
		return dep_lists[m]
	end
	local deps = get_deps(m)
	local t = {}
	--collect modules to a list, skipping excludes
	for k in pairs(deps) do
		if not exclude[k] then
			t[#t+1] = k
		end
	end
	--sort names by std then by name
	table.sort(t, function(a, b)
		if std[a] == std[b] then
			return a < b
		else
			return not std[b]
		end
	end)
	local s = table.concat(t, ', ')
	dep_lists[m] = s
	return s
end

--check if a module is a submodule of another module
local function is_submodule(m, parent)
	return m == parent or m:match('^'..parent..'[%.%_]')
end

--now that we trace require calls, we can load other modules that we need

local lfs = require'lfs'
local glue = require'glue'
local tuple = require'tuple'
--also, cjson is a runtime dependency for building the package db
--also, pp is a runtime dependency for inspect()

--recursive lfs.dir() -> iter() -> filename, path, mode
local function dir(p0, recurse)
	assert(p0)
	local function rec(p)
		local dp = p0 .. (p and '/' .. p or '')
		for f in lfs.dir(dp) do
			if f ~= '.' and f ~= '..' then
				local mode = lfs.attributes(dp .. '/' .. f, 'mode')
				coroutine.yield(f, p, mode)
				if recurse and mode == 'directory' then
					rec((p and p .. '/' .. f or f))
				end
			end
		end
	end
	return coroutine.wrap(rec)
end

--read a cmd output to a line iterator
local function pipe_lines(cmd)
	local f = assert(io.popen(cmd, 'rb'))
	f:setvbuf('full')
	return coroutine.wrap(function()
		for line in f:lines() do
			coroutine.yield(line)
		end
		f:close()
	end)
end

--read a cmd output to a string
local function read_pipe(cmd)
	local t = {}
	for line in pipe_lines(cmd) do
		t[#t+1] = line
	end
	return table.concat(t, '\n')
end

function gitp(package, args)
	return 'git --git-dir="_git/'..package..'/.git" '..args
end

--path/dir/file -> path/dir, file
local function split_path(path)
	local filename = path:match'([^/]*)$'
	local n = #path - #filename
	if n > 1 then n = n - 1 end --remove trailing / if not /
	return path:sub(1, n), filename
end

--"key <separator> value" -> key, value
local function split_kv(s, sep)
	sep = glue.escape(sep)
	return s:match('^([^'..sep..']*)%s*'..sep..'%s*(.*)$')
end

--parse the yaml header of a pandoc .md file, enclosed by '---' lines
local function parse_md_file(md_file, docname)
	local t = {}
	local f = io.open(md_file, 'r')
	if not f or f:read'*l' ~= '---' then
		error('no tags on '..md_file)
	end
	for s in f:lines() do
		if s == '---' then break end
		local k,v = split_kv(s, ':')
		k,v = k and glue.trim(k), v and glue.trim(v)
		if not k or k == '' then
			error('invalid tag '..s)
		elseif t[k] then
			error('duplicate tag '..k)
		else
			t[k] = v
		end
	end
	t.title = t.title or docname --set default title
	f:close()
	return t
end

--WHAT file -> {realname='', version='', url='', license='', dependencies={d1,...}}
local function parse_what_file(what_file)
	local t = {}
	local f = assert(io.open(what_file), 'WHAT file '.. what_file ..' missing')

	--parse the first line which has the format: '<realname> <version> from <url> (<license>)'
	local s = assert(f:read'*l', 'invalid WHAT file '.. what_file)
	t.realname, t.version, t.url, t.license = s:match('^%s*(.-)%s+(.-)%s+from%s+(.-)%s+%((.*)%)$')
	if not t.realname then
		error('invalid WHAT file '.. what_file)
	end
	t.license = t.license and t.license:match('^(.-)%s+'..glue.escape('license', '*i')..'$') or t.license
	t.license = t.license:match('^'..glue.escape('public domain', '*i')..'$') and 'PD' or t.license

	--parse the second line which has the format: 'requires: <pkg1>, <pkg2>, ...'
	t.dependencies = {}
	local s = f:read'*l'
	s = s and s:match'^%s*requires:%s*(.*)'
	if s then
		for s in glue.gsplit(s, ',') do
			s = glue.trim(s)
			if s ~= '' then
				t.dependencies[s] = true
			end
		end
	end

	f:close()
	return t
end

--path/*.lua -> Lua module name
local function lua_module_name(path)
	return path:gsub('/', '.'):match('(.-)%.lua$')
end

--path/*.dll|.so -> C module name
local function c_module_name(path)
	local ext = package.cpath:match'%?%.(.-);'
	local name = path:match('bin/[^/]+/clib/(.-)%.'..ext..'$')
	return name and name:gsub('/', '.')
end

local function module_name(path)
	return lua_module_name(path) or c_module_name(path)
end

--mod_submod -> mod; mod.submod -> mod
local function parent_module_name(mod)
	local parent = mod:match'(.-)[_%.][^_%.]+$'
	if not parent or parent == '' then return end
	return parent
end

--tree builder pattern based on a function that lists all names and a function that gets a parent's name
local function build_tree(get_names, get_parent)
	local parents = {}
	for name in get_names() do
		parents[name] = get_parent(name) or false
	end
	local root = {name = false}
	local function add_children(pnode)
		for name, parent in pairs(parents) do
			if parent == pnode.name then
				local node = {name = name}
				table.insert(pnode, node)
				add_children(node)
			end
		end
	end
	add_children(root)
	return root
end

--tree walker
local function walk_tree(t, f)
	local function walk_children(pnode, level)
		for i,node in ipairs(pnode) do
			f(node, level, pnode, i)
			walk_children(node, level + 1)
		end
	end
	walk_children(t, 0)
end


--data acquisition
---------------------------------------------------------------------------

local cache = {}

local function cached(k, f)
	if cache[k] == nil then
		if f ~= nil then
			cache[k] = f()
			assert(cache[k] ~= nil)
		else
			cache[k] = {}
		end
	end
	return cache[k]
end

--check if a path is valid for containing tracked files
local function is_valid_path(p)
	return not p or not (
		(p:match'^_' and not p:match'^_git/') --reserve _* for external stuff
		or p:match'^%.git/'
		or p:match'/%.git/'
	)
end

--check if a path is valid for containing docs
local function is_doc_path(p)
	return not p or not (
		p:match'^bin/'
		or p:match'^csrc/'
		or p:match'^media/'
	)
end

--check if a path is valid for containing modules
local function is_module_path(p)
	return not p or not (
		(p:match'^bin/' and not p:match'^bin/[^/]+/clib/')
		or p:match'^csrc/'
		or p:match'^media/'
	)
end

--check if a name is a module as opposed to a script or app
local function is_loadable_module(mod)
	return not (
		mod:match'_test$'
		or mod:match '_demo$'
		or mod:match'_benchmark$'
		or mod:match'_app$'
		or mod:match'^lexers%.'
	)
end

--get all the trackable files in current dir. recursively
local function disk_files()
	return cached('disk_files', function()
		local t = {}
		for f, p, mode in dir('.', '-R') do
			local path = (p and p .. '/' or '') .. f
			if mode ~= 'directory' and is_valid_path(path) then
				t[path] = true
			end
		end
		return t
	end)
end

--_git/<name>.exclude -> {name = true}
local function known_packages()
	return cached('known_packages', function()
		local t = {}
		for f in dir('_git') do
			local s = f:match'^(.-)%.exclude$'
			if s then t[s] = true end
		end
		return t
	end)
end

--_git/<name>/.git -> {name = true}
local function installed_packages()
	return cached('installed_packages', function()
		local t = {}
		for f, _, mode in dir('_git') do
			if mode == 'directory' and lfs.attributes('_git/'..f..'/.git', 'mode') == 'directory' then
				t[f] = true
			end
		end
		return t
	end)
end

--git ls-files -> {path = package}
local function tracked_files(package)
	return cached(tuple('files', package), function()
		local t = {}
		for path in pipe_lines(gitp(package, 'ls-files')) do
			t[path] = package
		end
		return t
	end)
end

--<doc>.md -> {doc = path}
local function docs(package)
	return cached(tuple('docs', package), function()
		local t = {}
		local files = tracked_files(package)
		for path in pairs(files) do
			if is_doc_path(path) then
				local dir, file = split_path(path)
				local name = file:match'^(.-)%.md$'
				if name then
					if t[name] then
						error('duplicate doc '..name..' as '..t[name]..' and '..path)
					end
					t[name] = path
				end
			end
		end
		return t
	end)
end

--<module>.lua -> {module = path}
local function modules(package)
	return cached(tuple('modules', package), function()
		local t = {}
		local files = tracked_files(package)
		for path in pairs(files) do
			if is_module_path(path) then
				local mod = module_name(path)
				if mod then
					t[mod] = path
				end
			end
		end
		return t
	end)
end

--csrc/<package>/WHAT -> {tag=val,...} | false
local function c_tags(package)
	return cached(tuple('c_tags', package), function()
		local what_file = string.format('csrc/%s/WHAT', package)
		return tracked_files(package)[what_file] and parse_what_file(what_file) or false
	end)
end

--<doc>.md -> {title='', project='', category=''}
local function doc_tags(package, doc)
	return cached(tuple('doc_tags', package, doc), function()
		local docs = docs(package)
		local path = docs[doc]
		return path and parse_md_file(path, doc) or false
	end)
end

--first ancestor module (parent, grandad etc) that actually exists
local function module_parent(package, mod)
	return cached(tuple('module_parent', package, mod), function()
		local mods = modules(package)
		local parent = parent_module_name(mod)
		if not parent then return false end
		return mods[parent] and parent or module_parent(package, parent)
	end)
end

--list of modules required by a module
local function module_deps(mod)
	return is_loadable_module(mod) and get_deps(mod) or {}
end

local function module_dep_list(mod)
	return is_loadable_module(mod) and get_dep_list(mod) or ''
end

--current git version
local function git_version(package)
	return cached(tuple('git_version', package), function()
		return read_pipe(gitp(package, 'describe --tags --long --always'))
	end)
end

--list of tags
local function git_tags(package)
	return cached(tuple('git_tags', package), function()
		local t = {}
		for tag in pipe_lines(gitp(package, 'tag')) do
			t[#t+1] = tag
		end
		return t
	end)
end

--current tag (TODO: the last tag is not necessarily the current tag, is it?)
local function git_tag(package)
	return cached(tuple('git_tag', package), function()
		return read_pipe(gitp(package, 'describe --tags --abbrev=0'))
	end)
end

--csrc/<package>/build-<platform>.sh -> {platform = true,...}
--<package>.md:platforms -> {platform = true,...}
local function platforms(package)
	return cached(tuple('platforms', package), function()
		--platforms are inferred from the name of the build script
		local t = {}
		for path in pairs(tracked_files(package)) do
			local platform = path:match('^csrc/'..glue.escape(package..'/build-')..'(.-)%.sh$')
			if platform then
				t[platform] = true
			end
		end
		--platforms can also be specified in the 'platforms' tag of the package doc file
		local tags = doc_tags(package, package)
		if tags and tags.platforms then
			for platform in glue.gsplit(tags.platforms, ',') do
				platform = glue.trim(platform)
				if platform ~= '' then
					t[platform] = true
				end
			end
		end
		return t
	end)
end

--package type (heuristic)
local function package_type(package)
	local has_c = c_tags(package)
	local has_lua = next(modules(package))
	local has_ffi = false
	for mod in pairs(modules(package)) do
		local deps = module_deps(mod)
		if deps.ffi then
			has_ffi = true
			break
		end
	end
	return
		has_ffi and 'Lua+ffi' or
		has_lua and not has_c and not has_ffi and 'Lua' or
		has_c and not has_lua and 'C' or
		has_c and has_lua and not has_ffi and 'Lua/C' or
		'other'
end

--build a module tree for a package based on naming conventions
local function module_tree(package)
	return cached(tuple('module_tree', package), function()
		local function get_names() return pairs(modules(package)) end
		local function get_parent(mod) return module_parent(package, mod) end
		return build_tree(get_names, get_parent)
	end)
end

--synthetic info for a module
local function module_tags(package, mod)
	return cached(tuple('module_tags', package, mod), function()
		local mod_path = modules(package)[mod]
		return {
			lang =
				lua_module_name(mod_path) and 'Lua'
				or c_module_name(mod_path) and 'C',
			kind =
				mod:match'_demo$' and 'demo app'
				or mod:match'_test$' and 'test unit'
				or 'module',
			doc = docs(package)[mod],
			demo_module = modules(package)[mod..'_demo'] and mod..'_demo',
			test_module = modules(package)[mod..'_test'] and mod..'_test',
		}
	end)
end

--infer a doc's category when it's not explicit.
local function doc_category(package, doc)
	return cached(tuple('doc_category', package, doc), function()
		local t = doc_tags(package, doc)
		if t and t.category then
			return t.category
		end
		if modules(package)[doc] then --it's a module doc
			local parent = module_parent(package, doc)
			if parent and docs(package, parent) then --which has a parent which is documented
				return docs(package, parent).title
			end
		end
		if doc ~= package then --it's an uncategorized doc, tie it to the package's doc
			if docs(package, package) then --but the package has a doc
				return docs(package, package).title
			end
			return package --package has no doc, create a category of its name
		else
			return 'Other' --default category for uncategorized package docs
		end
	end)
end

--building and updating the category tree
---------------------------------------------------------------------------

local TOC_FILE = '_site/toc.md'

--parse the table of contents file (which contains only a markdown bullet list) into a tree
local function parse_toc_file()
	local root = {name = 'root'}
	local parent = root
	local last_node = nil
	local parents = {}
	local indent = 2
	local f = io.open(TOC_FILE)
	for s in f:lines() do
		local spaces, name = s:match'^(%s+)%*%s*%[?(.-)%]?%s*$'
		if spaces then
			local node = {name = name}
			if #spaces > indent then
				table.insert(parents, parent)
				parent = last_node
				indent = indent + 2
			elseif #spaces < indent then
				parent = table.remove(parents)
				indent = indent - 2
			end
			table.insert(parent, node)
			last_node = node
		end
	end
	f:close()
	return root
end

--toc tree by merging of the toc file with the category tree
local function toc_tree()
	return cached('toc_tree', function()
		--get the current category tree
		local tt = parse_toc_file()
		--build a synthetic category tree
		local ct = {}
		for package in glue.sortedpairs(installed_packages()) do
			local function get_names() return pairs(docs(package)) end
			local function get_parent(doc) return doc_category(package, doc) end
			local pct = build_tree(get_names, get_parent)
			table.insert(ct, pct)
		end

		--remove non-existing leaf (doc) nodes
		--remove empty leafs
		--inject ct nodes in tt preserving order and hierarchy
		--TODO: all these
		return tt
	end)
end

local function rebuild_toc()
	local t = toc_tree()
	local f = io.open(TOC_FILE, 'wb')
	walk_tree(t, function(node, level)
		local s = node.name
		f:write(('  '):rep(level) .. '  * ' .. s .. '\n')
	end)
	f:close()
end


--building and updating the package database
---------------------------------------------------------------------------

local PACKAGES_JSON = '_site/packages.json'

local function package_record(package)
	return {
		name = package,
		tagline = doc_tags(package, package) and doc_tags(package, package).tagline,
		category = doc_category(package, package),
		type = package_type(package),
		git_version = git_version(package),
		git_tag = git_tag(package),
		c_version = c_tags(package) and ((c_tags(package).realname or name) .. ' ' .. c_tags(package).version),
		c_license = c_tags(package) and c_tags(package).license,
		platforms = platforms(package),
	}
end

local function rebuild_package_db()
	local db = {}
	for package in pairs(installed_packages()) do
		db[package] = package_record(package)
	end
	local cjson = require'cjson'
	glue.writefile(PACKAGES_JSON, cjson.encode(db))
end

--get packages db
local function package_db()
	local cjson = require'cjson'
	return cached('package_db', function()
		if not glue.fileexists(PACKAGES_JSON) then
			rebuild_package_db()
		end
		return cjson.decode(glue.readfile(PACKAGES_JSON))
	end)
end

--update a package in the json file and rewrite the file
local function update_package(package)
	assert(package, 'package missing')
	local cjson = require'cjson'
	local db = package_db()
	db[package] = package_record(package)
	glue.writefile(PACKAGES_JSON, cjson.encode(db))
end


--consistency checks
---------------------------------------------------------------------------

--check if more than one package tracks the same file
local function multitracked_files()
	local files = {} --{file = package}
	local dupes = {}
	for package in pairs(installed_packages()) do
		for path in pairs(tracked_files(package)) do
			if files[path] then
				dupes[path..' in '..package..' and '..files[path]] = true
			end
			files[path] = package
		end
	end
	return dupes
end

--check if there are files on disk that are not tracked by any git project
local function untracked_files()
	local untracked = disk_files()
	for package in pairs(installed_packages()) do
		for path in pairs(tracked_files(package)) do
			untracked[path] = false
		end
	end
	--trick: tracked_files('..') gets us GIT_DIR `_git/../.git` which is `.git`
	for path in pairs(tracked_files('..')) do
		untracked[path] = false
	end
	local t = {}
	for path, untracked in pairs(untracked) do
		if untracked then
			t[path] = true
		end
	end
	return t
end

--check for the same doc in a different path. since docs get converted into the same dir, this is not allowed.
local function duplicate_docs()
	local dt = {} --{doc = package}
	local dupes = {}
	for package in pairs(installed_packages()) do
		for doc, path in pairs(docs(package)) do
			if dt[doc] then
				dupes[doc..' in '..package..' and '..dt[doc]] = true
			end
		end
	end
	return dupes
end

--check for undocumented (thus invisible) packages
local function undocumented_packages()
	local t = {}
	for package in pairs(installed_packages()) do
		local docs = docs(package)
		if not docs[package] then
			--if any modules are documented that's ok too
			local hasdoc
			for mod in pairs(modules(package)) do
				if docs[mod] then
					hasdoc = true
					break
				end
			end
			if not hasdoc then
				t[package] = true
			end
		end
	end
	return t
end

--check for csrc dirs not matching package name
local function wrong_csrc_dirs()
	local t = {}
	for package in pairs(installed_packages()) do
		for path in pairs(tracked_files(package)) do
			local csrc_dir = path:match('^csrc/(.-)/')
			if csrc_dir then
				if csrc_dir ~= package then
					t[csrc_dir] = true
				end
			end
		end
	end
	return t
end

--check for wrong project tag in docs
local function wrong_project_tag(package)
	if not package then
		for package in pairs(installed_packages()) do
			wrong_project_tag(package)
		end
		return
	end
	local t = {}
	for doc in pairs(docs(package)) do
		local project_tag = doc_tags(package, doc).project
		if project_tag ~= package then
			t[doc] = true
		end
	end
	return t
end

--check for undocumented modules. lots cases when a module doesn't need documenting.
--all these modules don't need docuentation for any of their submodules.
local blacklisted_parents = {
	--external doc
	socket=1,
	lpeg=1,
	lexers=1,
	--single-page doc
	cplayer=1,
	hmac=1,
	fbclient=1,
	utf8=1,
	bitmap=1,
	winapi=1,
}
local function blacklisted_parent(mod) --TODO: review this check
	repeat
		mod = parent_module_name(mod)
		if blacklisted_parents[mod] then
			return true
		end
	until not mod
end
local function blacklisted_module(mod) --some modules don't need documenting
	return
		not is_loadable_module(mod)
		or mod:match'_h$'
		or blacklisted_parent(mod)
end
local function undocumented_modules(include_submodules)
	local t = {}
	for package in pairs(installed_packages()) do
		local docs = docs(package)
		local mods = modules(package)
		for mod in pairs(mods) do
			if not docs[mod] and not blacklisted_module(mod) then
				if include_submodules or not module_parent(package, mod) then
					t[mod] = true
				end
			end
		end
	end
	return t
end


--use as loadable module
---------------------------------------------------------------------------

local luapower = {
	--data acquisition
	disk_files = disk_files,
	known_packages = known_packages,
	installed_packages = installed_packages,
		tracked_files = tracked_files,
		docs = docs,
			doc_tags = doc_tags,
		modules = modules,
			module_parent = module_parent,
			is_loadable_module = is_loadable_module,
				module_deps = module_deps,
				module_dep_list = module_dep_list,
				module_tags = module_tags,
		c_tags = c_tags,
		git_version = git_version,
		git_tags = git_tags,
		platforms = platforms,
		package_type = package_type,
		module_tree = module_tree,
	--package db
	package_record = package_record,
	package_db = package_db,
	update_package = update_package,
	rebuild_package_db = rebuild_package_db,
	--
	toc_tree = toc_tree,
	rebuild_toc = rebuild_toc,
}

if ... == 'luapower' then
	return luapower
end


--use as cmdline script
---------------------------------------------------------------------------

local function list(t)
	for k in glue.sortedpairs(t) do
		print(k)
	end
end
local function list_packages(opt)
	list(opt == '--all' and known_packages() or installed_packages())
end

--generate a nice markdown page for a package
local function describe_package(package)
	assert(package, 'package missing')

	print('# '..package)

	local function h(s)
		print''
		print('## '..s)
		print''
	end

	h'Overview'

	local t = doc_tags(package, package)
	local tagline = t and t.tagline or ''
	print(string.format('  %-16s %s', 'tagline:', tagline))
	print(string.format('  %-16s %s', 'type:',    package_type(package)))
	print(string.format('  %-16s %s', 'tag:', git_tag(package)))
	print(string.format('  %-16s %s', 'version:', git_version(package)))
	local t = glue.keys(platforms(package)); table.sort(t)
	print(string.format('  %-16s %s', 'platforms:', #t > 0 and table.concat(t, ', ') or 'Lua'))

	if next(modules(package)) then
		h'Modules'
		walk_tree(module_tree(package), function(node, level)
			local t = doc_tags(package, node.name)
			local tagline = t and t.tagline or ''
			local mt = module_tags(package, node.name)
			print(string.format('%-36s %-10s %s', ('  '):rep(level) .. '  * ' .. node.name, mt.kind, tagline))
		end)

		h'Dependencies'
		local fmt = '%-24s %s'
		local sep = ('-'):rep(24)..' '..('-'):rep(64)
		print(string.format(fmt, 'module', 'dependencies'))
		print(sep)
		for mod in glue.sortedpairs(modules(package)) do
			if module_dep_list(mod) ~= '' then
				print(string.format(fmt, mod, module_dep_list(mod)))
			end
		end
		print(sep)
	end

	if c_tags(package) then
		h'C Lib'
		print(string.format('   csrc/%s/WHAT: %s', package, require'pp'.pformat(c_tags(package), '   ', nil, nil, nil, 2)))
	end

	if next(docs(package)) then
		h'Docs'

		local fmt = '%-24s %s'
		local sep = ('-'):rep(24)..' '..('-'):rep(64)
		print(string.format(fmt, 'title', 'tagline'))
		print(sep)
		for doc, path in glue.sortedpairs(docs(package)) do
			local t = doc_tags(package, doc)
			print(string.format(fmt, t.title, t.tagline))
		end
		print(sep)
	end
	print''
end

local function print_toc_tree()
	walk_tree(toc_tree(), function(node, level)
		print(('  '):rep(level) .. '  * ' .. node[0])
	end)
end

local function count(t)
	local n = 0
	for k in pairs(t) do n = n + 1 end
	return n
end
local function error_list(title, t)
	if not next(t) then return end
	local s = string.format('%s (%d)', title, count(t))
	print(s)
	print(('-'):rep(#s))
	for k in glue.sortedpairs(t) do
		print(k)
	end
	print''
end
local function consistency_checks(package)
	error_list('multitracked files', multitracked_files())
	error_list('untracked files', untracked_files())
	error_list('duplicate docs', duplicate_docs())
	error_list('undocumented packages', undocumented_packages())
	error_list('wrong project tag', wrong_project_tag(package))
	error_list('wrong csrc dirs', wrong_csrc_dirs())
	error_list('undocumented modules', undocumented_modules(true))
end

--dispatch based on cmdline arguments

local actions = {}

local function add_action(name, args, info, handler)
	local action = {name = name, args = args, info = info, handler = handler}
	actions[name] = action
	actions[#actions+1] = action
end

local function help()
	print(string.format('usage: %s <action> ...', arg[0]))
	print''
	print'actions:'
	print''
	for i,t in ipairs(actions) do
		print(string.format('  %-30s %s', t.name .. ' ' .. t.args, t.info))
	end
	print''
end

add_action('help', '', 'usage information', help)
add_action('packages', '[--all]', 'list installed packages; with --all, list all known packages', list_packages)
add_action('describe', '<package>', 'describe a package', describe_package)
add_action('toc', '', 'print the table of contents', print_toc_tree)
add_action('check', '[<package>]', 'consistency checks', consistency_checks)
add_action('update', '<package>', 'update package entry in '..PACKAGES_JSON, update_package)
add_action('rebuild', '', 'rebuild '..PACKAGES_JSON, rebuild_package_db)

actions[... or 'help'].handler(select(2, ...))

--describe_package'path2d'
