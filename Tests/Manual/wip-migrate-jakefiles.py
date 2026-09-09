#!/usr/bin/env python3
import os
import argparse
import re

def transform_jakefile(content):
    # 1. Replace legacy Narwhal header with modern Node equivalents and globals
    header_pattern = re.compile(
        r'var\s+ENV\s*=\s*require\("system"\)\.env\s*,\s*'
        r'FILE\s*=\s*require\("file"\)\s*,\s*'
        r'JAKE\s*=\s*require\("jake"\)\s*,\s*'
        r'task\s*=\s*JAKE\.task\s*,\s*'
        r'FileList\s*=\s*JAKE\.FileList\s*,\s*'
        r'app\s*=\s*require\("cappuccino/jake"\)\.app\s*,\s*'
        r'configuration\s*=\s*ENV\["CONFIG"\]\s*\|\|\s*ENV\["CONFIGURATION"\]\s*\|\|\s*ENV\["c"\]\s*\|\|\s*"Debug"\s*,\s*'
        r'OS\s*=\s*require\("os"\);',
        re.DOTALL
    )

    new_header = (
        'var ENV = process.env,\n'
        '    cp = require("child_process"),\n'
        '    fs = require("fs"),\n'
        '    path = require("path"),\n'
        '    task = JAKE.task,\n'
        '    FileList = JAKE.FileList,\n'
        '    app = CAPPUCCINO.Jake.applicationtask.app,\n'
        '    configuration = ENV["CONFIG"] || ENV["CONFIGURATION"] || ENV["c"] || "Debug";'
    )

    if header_pattern.search(content):
        content = header_pattern.sub(new_header, content)
    else:
        # Fallback for slight formatting deviations
        content = re.sub(r'var\s+ENV\s*=\s*require\("system"\)\.env\s*;?', 'var ENV = process.env, cp = require("child_process"), fs = require("fs"), path = require("path");', content)
        content = re.sub(r'var\s+FILE\s*=\s*require\("file"\)\s*;?', '', content)
        content = re.sub(r'var\s+OS\s*=\s*require\("os"\)\s*;?', '', content)
        content = re.sub(r'var\s+JAKE\s*=\s*require\("jake"\)\s*,?', '', content)
        content = content.replace('require("cappuccino/jake").app', 'CAPPUCCINO.Jake.applicationtask.app')

    # 2. Replace legacy path operations
    content = content.replace("FILE.join", "path.join")

    # 3. Replace print -> console.log
    content = re.sub(r'\bprint\s*\(', 'console.log(', content)

    # 4. Replace FILE.mkdirs -> fs.mkdirSync
    content = re.sub(
        r'FILE\.mkdirs\s*\(\s*(.*?)\s*\)\s*;',
        r'fs.mkdirSync(\1, { recursive: true });',
        content
    )

    # 5. Replace OS.system([...]) -> cp.execSync
    def replace_os_system(match):
        inner = match.group(1).strip()
        if inner.startswith('[') and inner.endswith(']'):
            elements_str = inner[1:-1]
            return f'cp.execSync([{elements_str}].join(" "), {{ stdio: "inherit" }});'
        return f'cp.execSync({inner}.join(" "), {{ stdio: "inherit" }});'

    content = re.sub(r'OS\.system\s*\(\s*(.*?)\s*\)\s*;', replace_os_system, content)

    # 6. Update legacy NativeHost path (used in the "desktop" task)
    content = content.replace('require("cappuccino/nativehost")', 'require("@objj/nativehost")')

    return content

def migrate(apply_changes):
    root_dir = "."
    candidates = []

    # Pass 1: Gather candidates
    for item in sorted(os.listdir(root_dir)):
        target_dir = os.path.join(root_dir, item)

        if not os.path.isdir(target_dir) or item.startswith('.') or item == "Build":
            continue

        jakefile_path = None
        for jf in ["Jakefile", "jakefile"]:
            test_path = os.path.join(target_dir, jf)
            if os.path.isfile(test_path):
                jakefile_path = test_path
                break

        if jakefile_path:
            candidates.append((target_dir, jakefile_path))

    print(f"Found {len(candidates)} candidate Jakefile(s).")

    if not apply_changes:
        print("Dry run mode. Use --apply to execute the transformations.")
        return

    # Pass 2: Apply transformations
    for target_dir, jakefile_path in candidates:
        with open(jakefile_path, "r") as f:
            original_content = f.read()

        transformed_content = transform_jakefile(original_content)

        new_path = os.path.join(target_dir, "Jakefile")

        # Ensure we don't end up with both 'jakefile' and 'Jakefile' on case-sensitive filesystems
        if jakefile_path != new_path:
            os.remove(jakefile_path)

        with open(new_path, "w") as f:
            f.write(transformed_content)

        print(f'Migrated: "{new_path}"')

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Modernize subsidiary Jakefiles.")
    parser.add_argument("--apply", action="store_true", help="Apply the transformations directly (no backups).")
    args = parser.parse_args()

    migrate(args.apply)
