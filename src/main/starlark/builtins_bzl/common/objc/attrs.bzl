# Copyright 2021 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Attributes common to Objc rules"""

load(":common/cc/cc_info.bzl", "CcInfo")
load(":common/objc/semantics.bzl", "semantics")

_COMPILING_RULE = {
    "srcs": attr.label_list(
        allow_files = True,
        flags = ["DIRECT_COMPILE_TIME_INPUT"],
        doc = """
The list of C, C++, Objective-C, and Objective-C++ source and header
files, and/or (`.s`, `.S`, or `.asm`) assembly source files, that are processed to create
the library target.
These are your checked-in files, plus any generated files.
Source files are compiled into .o files with Clang. Header files
may be included/imported by any source or header in the srcs attribute
of this target, but not by headers in hdrs or any targets that depend
on this rule.
Additionally, precompiled .o files may be given as srcs.  Be careful to
ensure consistency in the architecture of provided .o files and that of the
build to avoid missing symbol linker errors.""",
    ),
    "non_arc_srcs": attr.label_list(
        allow_files = True,
        flags = ["DIRECT_COMPILE_TIME_INPUT"],
        doc = """
The list of Objective-C files that are processed to create the
library target that DO NOT use Automatic Reference Counting (ARC).
The files in this attribute are treated very similar to those in the
srcs attribute, but are compiled without ARC enabled.""",
    ),
    "pch": attr.label(
        allow_single_file = [".pch"],
        flags = ["DIRECT_COMPILE_TIME_INPUT"],
        doc = """
Header file to prepend to every source file being compiled (both arc
and non-arc).
Use of pch files is actively discouraged in BUILD files, and this should be
considered deprecated. Since pch files are not actually precompiled this is not
a build-speed enhancement, and instead is just a global dependency. From a build
efficiency point of view you are actually better including what you need directly
in your sources where you need it.""",
    ),
    "defines": attr.string_list(doc = """
Extra <code>-D</code> flags to pass to the compiler. They should be in
the form <code>KEY=VALUE</code> or simply <code>KEY</code> and are
passed not only to the compiler for this target (as <code>copts</code>
are) but also to all <code>objc_</code> dependers of this target.
Subject to <a href="${link make-variables}">"Make variable"</a> substitution and
<a href="${link common-definitions#sh-tokenization}">Bourne shell tokenization</a>."""),
    "enable_modules": attr.bool(doc = """
Enables clang module support (via -fmodules).
Setting this to 1 will allow you to @import system headers and other targets:
@import UIKit;
@import path_to_package_target;"""),
    "linkopts": attr.string_list(doc = "Extra flags to pass to the linker."),
    "module_map": attr.label(allow_files = [".modulemap"], doc = """
custom Clang module map for this target. Use of a custom module map is discouraged. Most
users should use module maps generated by Bazel.
If specified, Bazel will not generate a module map for this target, but will pass the
provided module map to the compiler."""),
    "module_name": attr.string(doc = """
Sets the module name for this target. By default the module name is the target path with
all special symbols replaced by _, e.g. //foo/baz:bar can be imported as foo_baz_bar."""),
    # How many rules use this in the depot?
    "stamp": attr.bool(),
}

_COMPILE_DEPENDENCY_RULE = {
    "hdrs": attr.label_list(
        allow_files = True,
        flags = ["DIRECT_COMPILE_TIME_INPUT"],
        doc = """
The list of C, C++, Objective-C, and Objective-C++ header files published
by this library to be included by sources in dependent rules.
<p>
These headers describe the public interface for the library and will be
made available for inclusion by sources in this rule or in dependent
rules. Headers not meant to be included by a client of this library
should be listed in the srcs attribute instead.
<p>
These will be compiled separately from the source if modules are enabled.""",
    ),
    "textual_hdrs": attr.label_list(
        allow_files = True,
        flags = ["DIRECT_COMPILE_TIME_INPUT"],
        doc = """
The list of C, C++, Objective-C, and Objective-C++ files that are
included as headers by source files in this rule or by users of this
library. Unlike hdrs, these will not be compiled separately from the
sources.""",
    ),
    "includes": attr.string_list(
        doc = """
List of <code>#include/#import</code> search paths to add to this target
and all depending targets.

This is to support third party and open-sourced libraries that do not
specify the entire workspace path in their
<code>#import/#include</code> statements.
<p>
The paths are interpreted relative to the package directory, and the
genfiles and bin roots (e.g. <code>blaze-genfiles/pkg/includedir</code>
and <code>blaze-out/pkg/includedir</code>) are included in addition to the
actual client root.
<p>
Unlike <a href="${link objc_library.copts}">COPTS</a>, these flags are added for this rule
and every rule that depends on it. (Note: not the rules it depends upon!) Be
very careful, since this may have far-reaching effects.  When in doubt, add
"-iquote" flags to <a href="${link objc_library.copts}">COPTS</a> instead.""",
    ),
    "sdk_includes": attr.string_list(doc = """
List of <code>#include/#import</code> search paths to add to this target
and all depending targets, where each path is relative to
<code>$(SDKROOT)/usr/include</code>."""),
    "deps": attr.label_list(
        providers = [CcInfo],
        doc = """
The list of targets that this target depend on.""",
    ),
}

_SDK_FRAMEWORK_DEPENDER_RULE = {
    "sdk_frameworks": attr.string_list(doc = """
Names of SDK frameworks to link with (e.g. "AddressBook", "QuartzCore").

<p> When linking a top level Apple binary, all SDK frameworks listed in that binary's
transitive dependency graph are linked."""),
    "weak_sdk_frameworks": attr.string_list(doc = """
Names of SDK frameworks to weakly link with. For instance,
"MediaAccessibility".

In difference to regularly linked SDK frameworks, symbols
from weakly linked frameworks do not cause an error if they
are not present at runtime."""),
    "sdk_dylibs": attr.string_list(doc = """
Names of SDK .dylib libraries to link with. For instance, "libz" or
"libarchive".

"libc++" is included automatically if the binary has any C++ or
Objective-C++ sources in its dependency tree. When linking a binary,
all libraries named in that binary's transitive dependency graph are
used."""),
}

_COPTS_RULE = {
    "copts": attr.string_list(doc = """
Extra flags to pass to the compiler.
Subject to <a href="${link make-variables}">"Make variable"</a> substitution and
<a href="${link common-definitions#sh-tokenization}">Bourne shell tokenization</a>.
These flags will only apply to this target, and not those upon which
it depends, or those which depend on it.
<p>
Note that for the generated Xcode project, directory paths specified using "-I" flags in
copts are parsed out, prepended with "$(WORKSPACE_ROOT)/" if they are relative paths, and
added to the header search paths for the associated Xcode target."""),
    "conlyopts": attr.string_list(doc = """
Extra flags to pass to the compiler for C files.
Subject to <a href="${link make-variables}">"Make variable"</a> substitution and
<a href="${link common-definitions#sh-tokenization}">Bourne shell tokenization</a>.
These flags will only apply to this target, and not those upon which
it depends, or those which depend on it.
<p>
Note that for the generated Xcode project, directory paths specified using "-I" flags in
copts are parsed out, prepended with "$(WORKSPACE_ROOT)/" if they are relative paths, and
added to the header search paths for the associated Xcode target."""),
    "cxxopts": attr.string_list(doc = """
Extra flags to pass to the compiler for Objective-C++ and C++ files.
Subject to <a href="${link make-variables}">"Make variable"</a> substitution and
<a href="${link common-definitions#sh-tokenization}">Bourne shell tokenization</a>.
These flags will only apply to this target, and not those upon which
it depends, or those which depend on it.
<p>
Note that for the generated Xcode project, directory paths specified using "-I" flags in
copts are parsed out, prepended with "$(WORKSPACE_ROOT)/" if they are relative paths, and
added to the header search paths for the associated Xcode target."""),
}

_ALWAYSLINK_RULE = {
    "alwayslink": attr.bool(doc = """
If 1, any bundle or binary that depends (directly or indirectly) on this
library will link in all the object files for the files listed in
<code>srcs</code> and <code>non_arc_srcs</code>, even if some contain no
symbols referenced by the binary.
This is useful if your code isn't explicitly called by code in
the binary, e.g., if your code registers to receive some callback
provided by some service."""),
}

def _union(*dictionaries):
    result = {}
    for dictionary in dictionaries:
        result.update(dictionary)
    return result

common_attrs = struct(
    union = _union,
    ALWAYSLINK_RULE = _ALWAYSLINK_RULE,
    COMPILING_RULE = _COMPILING_RULE,
    COMPILE_DEPENDENCY_RULE = _COMPILE_DEPENDENCY_RULE,
    COPTS_RULE = _COPTS_RULE,
    LICENSES = semantics.get_licenses_attr(),
    SDK_FRAMEWORK_DEPENDER_RULE = _SDK_FRAMEWORK_DEPENDER_RULE,
)
