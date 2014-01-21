--luapower reflection library (Cosmin Apreutesei, public domain).
--leverages the many conventions in luapower to extract and aggregate metadata about
--packages, modules, and documentation and perform various consistency checks.
--it also generates and updates the list of packages and table of contents that
--are used on luapower.com. the entire API is memoized so it can be abused
--without worrying about doing multiple calls on the same arguments.

--NOTE: make sure this is the very first module that you require in your scripts,
--or dependency tracking won't work correctly.


--data acquisition: readers and parsers
--=========================================================================

--find dependencies of a module by tracing the `require` calls.
---------------------------------------------------------------------------

--libraries that we won't track because require'ing them is not necessary in any Lua version
local notrack_modules = {string=1, table=1, coroutine=1, package=1, io=1, math=1, os=1, _G=1, debug=1}

local modules = {} --{module = {dep1 = true, ...}}
local parents = {}
local require_ = require

function require(m)
	if notrack_modules[m] then
		return require_(m)
	end
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

local function module_requires(m) --direct dependencies
	if not modules[m] then
		assert(not next(parents))
		require(m)
		assert(not next(parents))
	end
	return modules[m]
end


--build the list of built-in modules before loading our own dependencies
---------------------------------------------------------------------------

local builtin_modules = {[0] = 0}
for k in pairs(package.loaded) do
	builtin_modules[k] = true
	builtin_modules[0] = builtin_modules[0] + 1
end
builtin_modules.ffi = true
builtin_modules.jit = true

if builtin_modules[0] > 14 then --14 counted in LuaJIT2 (above Lua 5.1 there's jit.opt, jit.util and bit)
	print[[
WARNING: modules were loaded before 'luapower' was loaded.
These modules are now considered to be built-in modules.
To avoid this warning, require'luapower' before any other modules.]]
end


--now that we trace require calls, we can load other modules that we need
---------------------------------------------------------------------------

local lfs = require'lfs'
local glue = require'glue'
local tuple = require'tuple'
--also, cjson is a runtime dependency for building the package db.
--also, pp is a runtime dependency for inspect()


--filesystem reader
---------------------------------------------------------------------------

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

--path/dir/file -> path/dir, file
local function split_path(path)
	local filename = path:match'([^/]*)$'
	local n = #path - #filename - 1
	if n > 1 then n = n - 1 end --remove trailing '/' if the path is not '/'
	return path:sub(1, n), filename
end


--git command output readers
---------------------------------------------------------------------------

--read a cmd output to a line iterator
local function pipe_lines(cmd)
	local f = assert(io.popen(cmd, 'r'))
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

--git command string for a package repo
function gitp(package, args)
	return 'git --git-dir="_git/'..package..'/.git" '..args
end


--module finders
---------------------------------------------------------------------------

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

--'module_submodule' -> 'module'; 'module.submodule' -> 'module'
local function parent_module_name(mod)
	local parent = mod:match'(.-)[_%.][^_%.]+$'
	if not parent or parent == '' then return end
	return parent
end


--tree builder and tree walker patterns
---------------------------------------------------------------------------

--tree builder based on a function that lists all names and a function that gets a parent's name
local function build_tree(get_names, get_parent)
	local parents = {}
	for name in get_names() do
		parents[name] = get_parent(name) or true
	end
	local root = {name = true}
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


--WHAT file parser
---------------------------------------------------------------------------

--WHAT file -> {realname='', version='', url='', license='', dependencies={d1,...}}
local function parse_what_file(what_file)
	local t = {}
	local f = assert(io.open(what_file))

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
	s = s and s:match'^[^:]*:(.*)'
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


--markdown yaml header parser
---------------------------------------------------------------------------

--"key <separator> value" -> key, value
local function split_kv(s, sep)
	sep = glue.escape(sep)
	local k,v = s:match('^([^'..sep..']*)'..sep..'(.*)$')
	k = k and glue.trim(k)
	if not k then return end
	v = glue.trim(v)
	if v == '' then v = true end --values default to true in pandoc
	return k,v
end

--parse the yaml header of a pandoc .md file, enclosed by lines containing only '---'
local function parse_md_file(md_file, docname)
	local t = {}
	local f = io.open(md_file, 'r')
	if not f or f:read'*l' ~= '---' then
		error('no tags on '..md_file)
	end
	for s in f:lines() do
		if s == '---' then break end
		local k,v = split_kv(s, ':')
		if not k then
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


--memoize pattern for functions with multiple arguments
---------------------------------------------------------------------------

local cache = {}
local NIL = {}
local function swap(v, a, b)
	if v == a then return b end
	return v
end
local function memoize(func)
	return function(...)
		local k = tuple(func, ...)
		if cache[k] == nil then
			cache[k] = swap(func(...), nil, NIL)
		end
		return swap(cache[k], NIL, nil)
	end
end


--data acquisition: logic and collection
--=========================================================================


--disk files, irrespective of git trackings
---------------------------------------------------------------------------

--check if a path is valid for containing tracked files
local function is_valid_path(p)
	return not p or not (
		(p:match'^_' and not p:match'^_git/') --reserve _* for external stuff
		or p:match'^%.git/'
		or p:match'/%.git/'
	)
end

--get all the trackable files in current dir. recursively
local disk_files = memoize(function()
	local t = {}
	for f, p, mode in dir('.', '-R') do
		local path = (p and p .. '/' or '') .. f
		if mode ~= 'directory' and is_valid_path(path) then
			t[path] = true
		end
	end
	return t
end)


--packages and their files
---------------------------------------------------------------------------

--_git/<name>.exclude -> {name = true}
local known_packages = memoize(function()
	local t = {}
	for f in dir('_git') do
		local s = f:match'^(.-)%.exclude$'
		if s then t[s] = true end
	end
	return t
end)

--_git/<name>/.git -> {name = true}
local installed_packages = memoize(function()
	local t = {}
	for f, _, mode in dir('_git') do
		if mode == 'directory' and lfs.attributes('_git/'..f..'/.git', 'mode') == 'directory' then
			t[f] = true
		end
	end
	return t
end)

--(known - installed) -> not installed
local not_installed_packages = memoize(function()
	local installed = installed_packages()
	local t = {}
	for package in pairs(known_packages()) do
		if not installed[package] then
			t[package] = true
		end
	end
	return t
end)

--wrapper for any function(package) that returns a table with keys that are unique accross all packages.
--it makes the package argument optional so that if not given, function(package) is called repeatedly
--for each installed package and the results are accumulated into a single table.
local function memoize_package(func)
	local memoized_func
	memoized_func = memoize(function(package, ...)
		if package then
			return func(package, ...)
		end
		local t = {}
		for package in pairs(installed_packages()) do
			glue.update(t, memoized_func(package, ...))
		end
		return t
	end)
	return memoized_func
end

--git ls-files -> {path = package}
local tracked_files = memoize_package(function(package)
	local t = {}
	for path in pipe_lines(gitp(package, 'ls-files')) do
		t[path] = package
	end
	return t
end)


--tracked files breakdown: modules, scripts, docs
---------------------------------------------------------------------------

--check if a path is valid for containing modules
local function is_module_path(p)
	return not p or not (
		(p:match'^bin/' and not p:match'^bin/[^/]+/clib/')
		or p:match'^csrc/'
		or p:match'^media/'
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

--check if a name is a module as opposed to a script or app
local function is_module(mod)
	return not (
		mod:match'_test$'
		or mod:match '_demo$'
		or mod:match'_benchmark$'
		or mod:match'_app$'
		or mod:match'^lexers%.' --TODO: these are not yet modules (they depend on their environment)
	)
end

--tracked <doc>.md -> {doc = path}
local docs = memoize_package(function(package)
	local t = {}
	for path in pairs(tracked_files(package)) do
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

local function modules_(package, should_be_module)
	local t = {}
	for path in pairs(tracked_files(package)) do
		if is_module_path(path) then
			local mod = module_name(path)
			if mod and is_module(mod) == should_be_module then
				t[mod] = path
			end
		end
	end
	return t
end
--tracked <module>.lua -> {module = path}
local modules = memoize_package(function(package) return modules_(package, true) end)
--tracked <script>.lua -> {script = path}
local scripts = memoize_package(function(package) return modules_(package, false) end)


--module trees
---------------------------------------------------------------------------

--first ancestor module (parent, grandad etc) that actually exists in the same package (or in all packages)
local function module_parent_(package, mod)
	local parent = parent_module_name(mod)
	if not parent then return end
	return modules(package)[parent] and parent or module_parent_(package, parent)
end
local module_parent = memoize(module_parent_)

--build a module tree for a package (or for all packages)
local module_tree = memoize(function(package)
	local function get_names() return pairs(modules(package)) end
	local function get_parent(mod) return module_parent(package, mod) end
	return build_tree(get_names, get_parent)
end)


--doc tags
---------------------------------------------------------------------------

--tracked <doc>.md -> {title='', project='', other yaml tags...}
local doc_tags = memoize(function(package, doc)
	local path = docs(package)[doc]
	return path and parse_md_file(path, doc)
end)


--reverse lookups
---------------------------------------------------------------------------

--reverse lookup of a package from a module
local module_package = memoize(function(mod)
	--shortcut: builtin module
	if builtin_modules[mod] then return end
	--shortcut: find the package that matches the module name or a module parent name
	local mod1 = mod
	while mod1 do
		if installed_packages()[mod1] then
			if modules(mod1)[mod1] then --confirm that the module is in the package
				return mod1
			end
		end
		mod1 = parent_module_name(mod1)
	end
	--the slow way: look in all packages for the module
	--print('going slow for '..mod..'...')
	local path = modules()[mod]
	return path and tracked_files()[path]
end)

--reverse lookup of a package from a doc
local doc_package = function(doc)
	--shortcut: package doc
	if installed_packages()[doc] and docs(doc)[doc] then
		return doc
	end
	--the slow way: look in all packages for the doc
	--print('going slow for '..doc..'...')
	local path = docs()[doc]
	return path and tracked_files()[path]
end


--package csrc info
---------------------------------------------------------------------------

local csrc_dir = memoize(function(package) --there should be only one csrc dir per package
	--shortcut: csrc dir matches package name
	if lfs.attributes('csrc/'..package, 'mode') == 'directory' then
		return 'csrc/'..package
	end
	for path in pairs(tracked_files(package)) do
		local dir = path:match'^(csrc/[^/]+)/'
		if dir then return dir end
	end
end)

--csrc/*/WHAT -> {tag=val,...}
local c_tags = memoize(function(package)
	if not csrc_dir(package) then return end
	local what_file = csrc_dir(package) .. '/WHAT'
	return glue.fileexists(what_file) and parse_what_file(what_file)
end)

--csrc/*/build-<platform>.sh -> {platform = true,...}
--<package>.md:platforms -> {platform = true,...}
local platforms = memoize_package(function(package)
	--platforms are inferred from the name of the build script
	local t = {}
	if not csrc_dir(package) then return t end
	for path in pairs(tracked_files(package)) do
		local platform = path:match('^'..glue.escape(csrc_dir(package)..'/build-')..'(.-)%.sh$')
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


--package git info
---------------------------------------------------------------------------

--current git version
local git_version = memoize(function(package)
	return read_pipe(gitp(package, 'describe --tags --long --always'))
end)

--list of tags
local git_tags = memoize(function(package)
	local t = {}
	for tag in pipe_lines(gitp(package, 'tag')) do
		t[#t+1] = tag
	end
	return t
end)

--current tag
local git_tag = memoize(function(package)
	return read_pipe(gitp(package, 'describe --tags --abbrev=0'))
end)


--module dependencies
---------------------------------------------------------------------------

--direct and indirect module dependencies of a module, as a table
local module_requires_all = memoize(function(mod)
	local t = {}
	local function add_deps(mod)
		for dep in pairs(module_requires(mod)) do
			t[dep] = true
			add_deps(dep)
		end
	end
	add_deps(mod)
	return t
end)

--direct and indirect module dependencies of a module, as a tree
local module_requires_tree = memoize(function(mod)
	local function add_deps(pnode)
		for dep in pairs(module_requires(pnode.name)) do
			local node = {name = dep}
			table.insert(pnode, node)
			add_deps(node)
		end
		return pnode
	end
	return add_deps({name = mod})
end)

--direct-external module dependencies of a module
local module_requires_ext = memoize(function(mod, package)
	package = package or module_package(mod)
	local t = {}
	local function add_deps(mod)
		for dep in pairs(module_requires(mod)) do
			if not modules(package)[dep] then --external dependency, record it and stop recursion
				t[dep] = true
			else --internal dependency, recurse
				add_deps(dep)
			end
		end
	end
	add_deps(mod)
	return t
end)

--direct and indirect C dependencies of a package
local c_deps = memoize_package(function(package)
	local deps = {}
	local function add_deps(package)
		local cdeps = c_tags(package) and c_tags(package).dependencies
		if not cdeps then return end
		for dep in pairs(cdeps) do
			if not known_packages()[dep] then
				print(string.format('WARNING: invalid C dependency in %s: %s', package, dep))
			end
			if not deps[dep] then
				deps[dep] = true
				add_deps(dep)
			end
		end
	end
	add_deps(package)
	return deps
end)

--package deps from a module_requires_* result table
local function package_deps_(mod, package, add_dep_c_deps, module_deps)
	package = package or module_package(mod)
	local deps = {}
	--add C deps to the mix (C deps apply to all modules in the package)
	glue.update(deps, c_deps(package))
	for mod in pairs(module_deps) do
		local dep_package = module_package(mod)
		assert(dep_package or builtin_modules[mod] or not is_module(mod), 'package not found for ' .. mod)
		if dep_package and dep_package ~= package then
			deps[dep_package] = true
			if add_dep_c_deps then
				glue.update(deps, c_deps(dep_package))
			end
		end
	end
	return deps
end

--direct and indirect package dependencies of a module
local module_requires_packages_all = memoize(function(mod, package)
	return package_deps_(mod, package, true, module_requires_all(mod, package))
end)

--direct-external package dependencies of a module
local module_requires_packages_ext = memoize(function(mod, package)
	return package_deps_(mod, package, false, module_requires_ext(mod, package))
end)

--direct and indirect package dependencies of a package
local package_requires_packages_all = memoize_package(function(package)
	local deps = {}
	for mod in pairs(modules(package)) do
		glue.update(deps, module_requires_packages_all(mod, package))
	end
	return deps
end)

--direct-external package dependencies of a package
local package_requires_packages_ext = memoize_package(function(package)
	local deps = {}
	for mod in pairs(modules(package)) do
		glue.update(deps, module_requires_packages_ext(mod, package))
	end
	return deps
end)

--all modules that depend on a module
local module_required_all = memoize(function(mod)
	local t = {}
	for package in pairs(installed_packages()) do
		for dmod in pairs(modules(package)) do
			if module_requires(dmod)[mod] then
				t[dmod] = true
			end
		end
	end
	return t
end)

--analytic info
---------------------------------------------------------------------------

--analytic info for a package
local package_type = memoize(function(package)
	local has_c = csrc_dir(package) and true or false
	local has_lua = next(modules(package)) and true or false
	local has_ffi = false
	for mod in pairs(modules(package)) do
		if module_requires_all(mod).ffi then
			has_ffi = true
			break
		end
	end
	return has_ffi and 'Lua+ffi' or has_lua and (has_c and 'Lua/C' or 'Lua') or has_c and 'C' or 'other'
end)

--analytic info for a module
local module_tags = memoize(function(package, mod)
	local mod_path = modules(package)[mod]
	return {
		lang =
			lua_module_name(mod_path) and 'Lua'
			or c_module_name(mod_path) and 'C',
		demo_module = scripts(package)[mod..'_demo'] and mod..'_demo',
		test_module = scripts(package)[mod..'_test'] and mod..'_test',
	}
end)


--web links
---------------------------------------------------------------------------

--external doc refs for referencing external docs for modules and packages
local EXTERNAL_REFS_FILE = '_site/external-refs.md.inc'
local external_refs = memoize(function()
	local t = {}
	for s in io.lines(EXTERNAL_REFS_FILE) do
		local ref, url = s:match'^%[([^%]]+)%]%:%s*(.*)$'
		t[ref] = url
	end
	return t
end)

--url for viewing a module's (or script's) source file
local module_source_url = memoize(function(package, mod)
	if modules(package)[mod] and module_tags(package, mod).lang ~= 'Lua' then return end
	local path = modules(package)[mod] or scripts(package)[mod]
	return 'https://github.com/luapower/' .. package .. '/blob/master/' .. path
end)

--best url for referencing a module: either a doc url, view-source url or external url or none
local module_doc_url = memoize(function(package, mod)
	if external_refs()[mod] then
		return external_refs()[mod]
	elseif package then
		if docs(package)[mod] then
			return mod .. '.html'
		else
			return module_source_url(package, mod)
		end
	end
end)

--url for viewing a package's browsing page
local package_source_url = memoize(function(package)
	return 'https://github.com/luapower/' .. package
end)

--best url for referencing a package: either a doc url or the github home url
local package_doc_url = memoize(function(package)
	if docs(package)[package] then
		return package .. '.html'
	else
		return package_source_url(package)
	end
end)


--building and updating the package database
--=========================================================================

local PACKAGES_JSON = '_site/packages.json'

local function link(text, url) --a link object to be used in json (url is optional)
	return {text, url}
end

local function module_name_cmp(a, b) --comparison function for table.sort() for modules: sorts built-ins first
	if builtin_modules[a] == builtin_modules[b] then
		--if a and be are in the same class, compare their names
		return a < b
	else
		--compare classes (std. vs non-std. module)
		return not builtin_modules[b]
	end
end

local function module_dep_links(package, mod)
	local t = {}
	for dep in pairs(module_requires_ext(mod, package)) do
		local dep_package = module_package(dep)
		table.insert(t, link(dep, module_doc_url(dep_package, dep)))
	end
	table.sort(t, function(a, b) return module_name_cmp(a[1], b[1]) end)
	return t
end

local function package_dep_links(package, mod)
	local t = {}
	local deps = mod and
		module_requires_packages_ext(mod, package) or
		package_requires_packages_ext(package)
	for dep in pairs(deps) do
		table.insert(t, link(dep, package_doc_url(dep)))
	end
	table.sort(t, function(a, b) return a[1] < b[1] end) --sort by link text
	return t
end

local function package_record(package)
	local modt = {}
	for mod in pairs(modules(package)) do
		if docs(package)[mod] then
			local tags = module_tags(package, mod)
			modt[mod] = {
				source_link = link('source', module_source_url(package, mod)),
				test_link = tags.test_module and link('test', module_doc_url(package, tags.test_module)),
				demo_link = tags.demo_module and link('demo', module_doc_url(package, tags.demo_module)),
				mdep_links = module_dep_links(package, mod),
				pdep_links = package_dep_links(package, mod),
			}
		end
	end
	local ptype = package_type(package)
	local dtags = doc_tags(package, package) or {}
	local ctags = c_tags(package) or {}
	return {
		name = package,
		tagline = dtags.tagline,
		link = link(package, package_doc_url(package)),
		--category = doc_category(package),
		type = ptype,
		--git_version = git_version(package),
		git_tag = git_tag(package),
		c_link = ctags.realname and link(ctags.realname .. ' ' .. ctags.version, ctags.url),
		--c_realname = ctags.realname,
		--c_version = ctags.version,
		--c_url = ctags.url,
		c_license = ctags.license,
		platforms = platforms(package),
		--pdep_links = package_dep_links(package),
		modules = modt,
	}
end

local function write_package_db(db)
	local cjson = require'cjson'
	glue.writefile(PACKAGES_JSON, cjson.encode(db))
end

local function rebuild_package_db()
	local db = {}
	for package in pairs(installed_packages()) do
		print(package..'...')
		db[package] = package_record(package)
	end
	write_package_db(db)
end

--get packages db
local package_db = memoize(function()
	local cjson = require'cjson'
	if not glue.fileexists(PACKAGES_JSON) then
		rebuild_package_db()
	end
	return cjson.decode(glue.readfile(PACKAGES_JSON))
end)

--update a package in the json file and rewrite the file
local function update_package_db(package)
	if package then
		local cjson = require'cjson'
		local db = package_db()
		db[package] = package_record(package)
		write_package_db(db)
	else
		rebuild_package_db()
	end
end


--building and updating the category tree
--=========================================================================

local TOC_FILE = '_site/toc.md'

--parse the table of contents file into a tree.
--the file should only contain a markdown bullet list indented with 4 spaces.
local function parse_toc_file()
	local root = {name = true}
	local parent = root
	local last_node = nil
	local parents = {}
	local indent = 0
	local f = io.open(TOC_FILE)
	if not f then
		return root
	end
	for s in f:lines() do
		local spaces, name, doc = s:match'^(\t*)%*%s*%[([^%]]+)%]%(([^%)]+)%.html%)%s*$' -- " * [name](doc.html)"
		if not spaces then
			spaces, name, doc = s:match'^(\t*)%*%s*%[([^%]]+)%]%[([^%]]+)%]%s*$' -- " * [name][doc]"
		end
		if not spaces then
			spaces, name = s:match'^(\t*)%*%s*%[([^%]]+)%]%s*$' -- " * [name]"
			doc = name
		end
		if not spaces then
			spaces, name = s:match'^(\t*)%*%s*(.-)%s*$' -- " * name"
		end
		if spaces then
			local node = {name = name, doc = doc}
			if #spaces > indent then
				table.insert(parents, parent)
				parent = last_node
				indent = indent + 1
			elseif #spaces < indent then
				parent = table.remove(parents)
				indent = indent - 1
			end
			table.insert(parent, node)
			last_node = node
		end
	end
	f:close()
	return root
end

local function write_toc_file(toc_tree)
	local f = io.open(TOC_FILE, 'wb')
	walk_tree(toc_tree, function(node, level)
		local s = (node.doc and '['..node.name..']' or node.name) ..
						(node.doc and node.name ~= node.doc and '['..node.doc..']' or '')
		f:write(('\t'):rep(level) .. '* ' .. s .. '\n')
	end)
	f:close()
	os.execute('sh _site/convert.sh _site/toc.md')
end

local toc_file = memoize(parse_toc_file)

local uncategorized_docs = memoize_package(function(package)
	local docs = docs(package)
	local found = {}
	walk_tree(toc_file(), function(node)
		if docs[node.doc] then
			found[node.doc] = true
		end
	end)
	local t = {}
	for doc in pairs(docs) do
		if not found[doc] then
			t[doc] = true
		end
	end
	return t
end)

local function subnode(pnode, name)
	for i,node in ipairs(pnode) do
		if node.name == name then
			return node
		end
	end
end

local function spare_node()
	local node = subnode(toc_file(), 'Other')
	if not node then
		node = {name = 'Other'}
		table.insert(toc_file(), node)
	end
	return node
end

local function toc_node(package, doc)
	return {name = doc_tags(package, doc).title, doc = doc}
end

local function update_toc_file(package) --package is optional
	--add missing docs to the TOC
	local t
	for package1 in pairs(installed_packages()) do
		if not package or package1 == package then
			for doc in pairs(uncategorized_docs(package)) do
				t = t or spare_node()
				t[#t+1] = toc_node(package, doc)
			end
		end
	end
	--update node names from doc title tags
	walk_tree(toc_file(), function(node, level, parent)
		if node.doc and docs(package)[node.doc] then
			local this_package = package or doc_package(node.doc)
			node.name = doc_tags(this_package, node.doc).title
		end
	end)
	write_toc_file(toc_file())
end

--full path of a doc in the TOC
local doc_category = memoize(function(doc, separator)
	separator = separator or ' > '
	local parents = {}
	local last_level = 0
	local found
	walk_tree(toc_file(), function(node, level, parent)
		if found then return end
		if level > last_level then
			table.insert(parents, parent)
		elseif level < last_level then
			table.remove(parents)
		end
		if node.doc == doc then
			found = true
		end
		last_level = level
	end)
	if found then
		local t = {}
		for i,p in ipairs(parents) do
			t[#t+1] = p.name
		end
		return table.concat(t, separator)
	else
		return 'Other'
	end
end)


--consistency checks
--=========================================================================

--check if more than one package tracks the same file
local multitracked_files = memoize(function()
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
end)

--check if there are files on disk that are not tracked by any git project
local untracked_files = memoize(function()
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
end)

--check for the same doc in a different path. since docs get converted into the same dir, this is not allowed.
local duplicate_docs = memoize(function()
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
end)

--check for undocumented packages
local undocumented_package = memoize_package(function(package)
	local t = {}
	local docs = docs(package)
	if not docs[package] then
		t[package] = true
	end
	return t
end)

--check for csrc dir not matching package name
local nonstandard_csrc_dir = memoize_package(function(package)
	local t = {}
	local dir = csrc_dir(package)
	if dir and dir ~= 'csrc/'..package then
		t[dir] = true
	end
	return t
end)

--check for wrong project tag in docs
local wrong_project_tag = memoize_package(function(package)
	local t = {}
	for doc in pairs(docs(package)) do
		local project_tag = doc_tags(package, doc).project
		if project_tag ~= package then
			t[doc] = true
		end
	end
	return t
end)

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
local function blacklisted_parent(mod)
	repeat
		mod = parent_module_name(mod)
		if blacklisted_parents[mod] then
			return true
		end
	until not mod
end
local function blacklisted_module(mod) --some modules don't need documenting
	return
		mod:match'_h$'
		or blacklisted_parent(mod)
end
local undocumented_modules = memoize_package(function(package, include_submodules)
	local t = {}
	local docs = docs(package)
	for mod in pairs(modules(package)) do
		if not docs[mod] and not blacklisted_module(mod) then
			if include_submodules or not module_parent(package, mod) then
				t[mod] = true
			end
		end
	end
	return t
end)

--check for any links in TOC that don't have a tracked md file
local toc_unsourced_links = memoize(function()
	local t = {}
	local docs = docs()
	walk_tree(toc_file(), function(node)
		if node.doc and not docs[node.doc] then
			t[node.doc] = true
		end
	end)
	return t
end)


--use as module
--=========================================================================

local luapower = {
	--info API
	disk_files = disk_files,
	known_packages = known_packages,
	not_installed_packages = not_installed_packages,
	installed_packages = installed_packages,
		tracked_files = tracked_files,
		docs = docs,
			doc_tags = doc_tags,
			doc_package = doc_package,
		modules = modules,
			module_parent = module_parent,
			module_tree = module_tree,
			module_package = module_package,
			module_requires = module_requires,
			module_requires_all  = module_requires_all,
			module_requires_tree = module_requires_tree,
			module_requires_ext  = module_requires_ext,
			module_requires_packages_all = module_requires_packages_all,
			module_requires_packages_ext = module_requires_packages_ext,
			module_required_all = module_required_all,
			module_tags = module_tags,
			module_source_url = module_source_url,
			module_doc_url = module_doc_url,
		scripts = scripts,
		c_tags = c_tags,
		c_deps = c_deps,
		git_version = git_version,
		git_tags = git_tags,
		git_tag = git_tag,
		platforms = platforms,
		package_type = package_type,
		package_source_url = package_source_url,
		package_doc_url = package_doc_url,
	--links
	external_refs = external_refs,
	--toc file
	toc_file = toc_file,
	update_toc_file = update_toc_file,
	--package db
	package_db = package_db,
	update_package_db = update_package_db,
	--consistency checks / global
	multitracked_files = multitracked_files, --wrong *.exclude patterns?
	untracked_files = untracked_files, --forgot to git add?
	duplicate_docs = duplicate_docs, --typo? name clash?
	toc_unsourced_links = toc_unsourced_links, --old html files?
	--consistency checks / per package
	undocumented_package = undocumented_package, --can't even download it
	wrong_project_tag = wrong_project_tag, --typo? forgot to rename?
	nonstandard_csrc_dir = nonstandard_csrc_dir, --shouldn't happen anymore
	undocumented_modules = undocumented_modules, --not blacklisted? too early to document?
	uncategorized_docs = uncategorized_docs, --forgot to add them to the TOC?
}

if ... == 'luapower' then
	return luapower
end


--use as cmdline script
--=========================================================================

--listing helpers
---------------------------------------------------------------------------

local function list_values(t)
	for i,k in ipairs(t) do
		print(k)
	end
end

local function list_keys(t, cmp)
	for k in glue.sortedpairs(t, cmp) do
		print(k)
	end
end

local function enum_values(t)
	return table.concat(t, ', ')
end

local function enum_keys(kt, cmp)
	local t = {}
	for k in glue.sortedpairs(kt, cmp) do
		t[#t+1] = k
	end
	return enum_values(t)
end

local function list_tree(t)
	walk_tree(t, function(node, level)
		print(('  '):rep(level) .. node.name)
	end)
end

local function lister(lister)
	return function(handler, cmp)
		return function(...)
			lister(handler(...), cmp)
		end
	end
end
local values_lister = lister(list_values)
local keys_lister = lister(list_keys)
local tree_lister = lister(list_tree)

local function count(t)
	local n = 0
	for k in pairs(t) do n = n + 1 end
	return n
end
local function list_errors(title, t)
	if not next(t) then return end
	local s = string.format('%s (%d)', title, count(t))
	print(s)
	print(('-'):rep(#s))
	list_keys(t)
	print''
end

local function package_lister(handler, lister, enumerator)
	lister = lister or print
	enumerator = enumerator or glue.pass
	return function(package, ...)
		if package then
			local v = handler(package, ...)
			if v then lister(v) end
		else
			for package in glue.sortedpairs(installed_packages()) do
				local v = handler(package, ...)
				if v then print(string.format('%-16s %s', package, enumerator(v))) end
			end
		end
	end
end

local function list_ctags(t)
	print(string.format('  %-20s: %s', 'realname', t.realname))
	print(string.format('  %-20s: %s', 'version', t.version))
	print(string.format('  %-20s: %s', 'url', t.url))
	print(string.format('  %-20s: %s', 'license', t.license))
	print(string.format('  %-20s: %s', 'dependencies', enum_keys(t.dependencies)))
end

local function list_mtags(package, mod)
	if not package then
		for package in pairs(installed_packages()) do
			list_mtags(package)
		end
	elseif not mod or mod == '--all' then
		for mod in pairs(modules(package)) do
			list_mtags(package, mod)
		end
	else
		local mt = module_tags(package, mod)
		local flags = {}
		if mt.test_module then table.insert(flags, 'test') end
		if mt.demo_module then table.insert(flags, 'demo') end
		print(string.format('%-16s %-24s %-6s %-4s', package, mod, mt.lang, table.concat(flags, ', ')))
	end
end

local function enum_ctags(t)
	return string.format('%-24s %-16s %-16s %-36s', t.realname, t.version, t.license, t.url)
end

--command handlers
---------------------------------------------------------------------------

local function consistency_checks(package)
	--global checks, only enabled if package is not specified
	if not package then
		list_errors('multitracked files', multitracked_files())
		list_errors('untracked files', untracked_files())
		list_errors('duplicate docs', duplicate_docs())
		list_errors('toc unknown links', toc_unsourced_links())
	end
	--package-specific checks (they also work with no package specified)
	list_errors('undocumented packages', undocumented_package(package))
	list_errors('wrong project tag', wrong_project_tag(package))
	list_errors('non-standard csrc dir', nonstandard_csrc_dir(package))
	list_errors('undocumented modules', undocumented_modules(package, false))
	list_errors('uncategorized docs', uncategorized_docs(package))
end

--generate a nice markdown page for a package
local function describe_package(package)
	local function h(s)
		print''
		print('## '..s)
		print''
	end

	h'Overview'
	local dtags = doc_tags(package, package) or {}
	print(string.format('  %-20s: %s', 'name', package))
	print(string.format('  %-20s: %s', 'tagline', dtags.tagline or ''))
	print(string.format('  %-20s: %s', 'type', package_type(package)))
	print(string.format('  %-20s: %s', 'tag', git_tag(package)))
	print(string.format('  %-20s: %s', 'tags', enum_values(git_tags(package))))
	print(string.format('  %-20s: %s', 'version', git_version(package)))
	print(string.format('  %-20s: %s', 'platforms:', enum_keys(platforms(package))))
	print(string.format('  %-20s: %s', 'url:', package_source_url(package)))
	print(string.format('  %-20s: %s', 'csrc dir:', csrc_dir(package) or ''))

	if next(modules(package)) then
		h'Modules'
		walk_tree(module_tree(package), function(node, level)
			local mod = node.name
			local dt = doc_tags(package, mod) or {}
			local mt = module_tags(package, mod)
			local deps = module_requires_ext(mod, package)
			local flags = (mt.test_module and 'T' or '') .. (mt.demo_module and 'D' or '')
			print(string.format('%-30s %-6s %-4s %s',
				('  '):rep(level) .. '  ' .. mod, mt.lang, flags, enum_keys(deps, module_name_cmp)))
		end)

		h'Dependencies'
		local mdeps = {}
		for mod in pairs(modules(package)) do
			glue.update(mdeps, module_requires_ext(mod, package))
		end
		print(string.format('  %-20s: %s', 'modules  (external)', enum_keys(mdeps, module_name_cmp)))
		print(string.format('  %-20s: %s', 'packages (external)', enum_keys(package_requires_packages_ext(package))))
		print(string.format('  %-20s: %s', 'packages (all)',      enum_keys(package_requires_packages_all(package))))
	end

	if next(scripts(package)) then
		h'Scripts'
		list_keys(scripts(package))
	end

	if c_tags(package) then
		h'C Lib'
		list_ctags(c_tags(package))
	end

	if next(docs(package)) then
		h'Docs'
		for doc, path in glue.sortedpairs(docs(package)) do
			local t = doc_tags(package, doc)
			print(string.format('  %-20s %s', t.title, t.tagline or ''))
		end
	end
	print''
end

local function update_package(package)
	update_package_db(package)
	update_toc_file(package)
end

--command dispatcher
---------------------------------------------------------------------------

local actions = {}
local action_list = {}

local function add_action(name, args, info, handler)
	local action = {name = name, args = args, info = info, handler = handler}
	actions[name] = action
	action_list[#action_list+1] = action
end

local function add_section(title)
	action_list[#action_list+1] = {title = title}
end

local function help()
	print''
	print(string.format('USAGE: luapower <command> ...', arg[0]))
	for i,t in ipairs(action_list) do
		if t.name then
			print(string.format('   %-30s %s', t.name .. ' ' .. t.args, t.info))
		elseif t.title then
			print''
			print(t.title)
			print''
		end
	end
	print''
	print'The `package` arg defaults to the env var PROJECT, as set by the `proj` command,'
	print'and if that is not set, it defaults to `--all`, meaning all packages.'
	print''
end

local function assert_arg(ok, ...)
	if ok then return ok,... end
	print''
	print('ERROR: '..(...))
	help()
	os.exit(1)
end

--wrapper for command handlers that take <package> as arg#1 -- provides its default value.
local function package_arg(handler, package_required)
	return function(package, ...)
		if package == '--all' then
			package = nil
		else
			package = package or os.getenv'PROJECT'
		end
		assert_arg(package or not package_required, 'package required')
		assert_arg(not package or installed_packages()[package], 'unknown package '..tostring(package))
		return handler(package, ...)
	end
end

add_section'HELP'
add_action('help', '', 'this screen', help)

add_section'PACKAGES'
add_action('packages', '', 'list installed packages', keys_lister(installed_packages))
add_action('known',    '', 'list all known package', keys_lister(known_packages))
add_action('left',     '', 'list not yet installed packages', keys_lister(not_installed_packages))

add_section'PACKAGE INFO'
add_action('describe',  '<package>', 'describe a package', package_arg(describe_package, true))
add_action('type',      '[package]', 'package type', package_arg(package_lister(package_type)))
add_action('ver',       '[package]', 'current git version', package_arg(package_lister(git_version)))
add_action('tags',      '[package]', 'git tags', package_arg(package_lister(git_tags, list_values, enum_values)))
add_action('tag',       '[package]', 'current git tag', package_arg(package_lister(git_tag)))
add_action('files',     '[package]', 'tracked files', package_arg(keys_lister(tracked_files)))
add_action('docs',      '[package]', 'docs', package_arg(keys_lister(docs)))
add_action('modules',   '[package]', 'modules', package_arg(keys_lister(modules)))
add_action('scripts',   '[package]', 'scripts', package_arg(keys_lister(scripts)))
add_action('mtree',     '[package]', 'module tree', package_arg(tree_lister(module_tree)))
add_action('mtags',     '[package [module]]',  'module info', package_arg(list_mtags))
add_action('platforms', '[package]', 'supported platforms', package_arg(package_lister(platforms, list_keys, enum_keys)))
add_action('ctags',     '[package]', 'C package info', package_arg(package_lister(c_tags, list_ctags, enum_ctags)))

add_section'CHECKS'
add_action('check',        '[package]', 'consistency checks', package_arg(consistency_checks))
add_action('trackable',    '',          'trackable files', keys_lister(disk_files))
add_action('multitracked', '',          'files tracked by multiple packages', keys_lister(multitracked_files))
add_action('untracked',    '',          'files not tracked by any package', keys_lister(untracked_files))

add_section'DATABASE'
add_action('update-db',  '[package]', 'update '..PACKAGES_JSON, package_arg(update_package_db))
add_action('update-toc', '[package]', 'update '..TOC_FILE, package_arg(update_toc_file))
add_action('update',     '[package]', 'update both '..PACKAGES_JSON..' and '..TOC_FILE, package_arg(update_package))

add_section'DEPENDENCIES'
add_action('requires', '<module>', 'direct module requires', keys_lister(module_requires))
add_action('rall',     '<module>', 'direct and indirect module requires', keys_lister(module_requires_all))
add_action('rtree',    '<module>', 'module require log tree', tree_lister(module_requires_tree))
add_action('rext',     '<module>', 'direct-external module requires', keys_lister(module_requires_ext))
add_action('pall',     '<module>', 'direct and indirect package dependencies', keys_lister(module_requires_packages_all))
add_action('pext',     '<module>', 'direct-external package dependencies', keys_lister(module_requires_packages_ext))
add_action('ppall',    '[package]', 'direct and indirect package dependencies', keys_lister(package_requires_packages_all))
add_action('ppext',    '[package]', 'direct-external package dependencies', keys_lister(package_requires_packages_ext))
add_action('cdeps',    '[package]', 'direct and indirect C dependencies', keys_lister(c_deps))
add_action('rrev',     '<module>', 'all modules that require a module', keys_lister(module_required_all))

local function run(action, ...)
	action = action or 'help'
	if not actions[action] then
		print''
		print('ERROR: unknown command '..action)
		action = 'help'
	end
	actions[action].handler(...)
end

run(...)
