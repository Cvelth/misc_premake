local template = {}

template.vpaths = {}
template.language = "C++"
template.cppdialect = "C++latest"
template.manifest_path = nil

function template.third_party(filename)
    local third_party = require(path.getrelative(_SCRIPT_DIR, _MAIN_SCRIPT_DIR) .. "/third_party/third_party")
    third_party.acquire(filename)
    depends = third_party.depends
    depends_on_everything = third_party.depends_on_everything
end

function template.workspace(name) workspace(name)
    configurations { "release", "debug" }
    architecture "x86_64"
    
    filter "configurations:debug"
        defines { "_DEBUG" }
        symbols "On"
        optimize "Debug"
    filter "configurations:release"
        defines { "NDEBUG" }
        optimize "Full"
        flags { "NoBufferSecurityCheck", "NoRuntimeChecks" }
    filter "action:vs*"
        flags { "MultiProcessorCompile", "NoMinimalRebuild" }
        linkoptions { "/ignore:4006", "/ignore:4099" }
        defines {
            "_CRT_SECURE_NO_DEPRECATE",
            "_CRT_SECURE_NO_WARNINGS",
            "_CRT_NONSTDC_NO_WARNINGS"
        }
    filter {}

    newoption {
        trigger = "output_directory",
        description = "A directory path for output binaries to be moved to.",
        value = "path"
    }
    newoption {
        trigger = "build_directory",
        description = "A directory path for temporary files to be generated in.",
        value = "path"
    }
    
    targetdir (_OPTIONS["output_directory"]
        or "output/%{cfg.system}_%{cfg.buildcfg}")
    location (_OPTIONS["build_directory"] or "build")
end

function template.location(suffix)
    location ((_OPTIONS["build_directory"] or "build") .. "/" .. (suffix or ""))
end

local function local_force_cppdialect(value)
    cppdialect(value)
    if value == "C++latest" then
        filter "action:xcode*"
            xcodebuildsettings {
                ["CLANG_CXX_LANGUAGE_STANDARD"] = "c++2a";
            }
            targetdir(_OPTIONS["output_directory"] or "output/%{cfg.system}_%{cfg.buildcfg}")
        filter "action:gmake*"
            buildoptions "-std=c++2a"
        filter {}
    end
end

function template.project(name) project(name)
    targetdir (_OPTIONS["output_directory"] or "output/%{cfg.system}_%{cfg.buildcfg}")
    template.location ""
    language(template.language)
    local_force_cppdialect(template.cppdialect)
    flags "FatalWarnings"
    warnings "Extra"

    filter "action:vs*"
        buildoptions "/utf-8"
    filter {}

    includedirs {
        "include",
        "source"
    }
    
    if template.vpaths then
        if type(template.vpaths) == "table" then
            vpaths(template.vpaths)
        elseif type(template.vpaths) == "function" then
            vpaths(template.vpaths(name))
        else
            print("Error: Unsupported 'template.vpaths' value ignored. "
                .. "It has to either be a static 'vpaths' table or "
                .. "a function accepting project name and returning a 'vpaths' table.")
        end
    end
end

function template.files(name, prefix)
    if prefix then
        files {
            prefix .. "/" .. name .. "/include/**.hpp",
            prefix .. "/" .. name .. "/source/**.hpp",
            prefix .. "/" .. name .. "/source/**.cpp"
        }
        includedirs {
            prefix .. "/" .. name .. "/include/",
            prefix .. "/" .. name .. "/source/"
        }
    else
        files {
            "include/" .. name .. "/**.hpp",
            "source/" .. name .. "/**.hpp",
            "source/" .. name .. "/**.cpp"
        }
    end
end

function template.pch(name, prefix)
    pchheader("precompiled/" .. name .. ".hpp")

    if prefix then
        pchsource(prefix .. "/" .. name .. "/source/precompiled/" .. name .. ".cpp")
        files { prefix .. "/" .. name .. "/source/precompiled/" .. name .. ".*pp" }
        includedirs { prefix .. "/" .. name .. "/source/" }
    else
        pchsource("source/precompiled/" .. name .. ".cpp")
        files { "source/precompiled/" .. name .. ".*pp" }
    end
end

function template.kind(value)
    kind(value)
    filter "action:vs*"
        if value == "ConsoleApp" or value == "WindowedApp" then
            if template.manifest_path then
                files(template.manifest_path)
            end
        end
    filter {}
end

return template