import os
import re

package_name = 'sawitappmobile'
lib_dir = r'c:\laragon\www\successmandiri_mobile\lib'

# Create a map of all files in lib for quick lookup
file_map = {}
for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            rel_path = os.path.relpath(os.path.join(root, file), lib_dir).replace('\\', '/')
            file_map[file] = rel_path

def fix_imports(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    changed = False
    new_lines = []
    
    # Relative path of current file from lib
    current_rel_dir = os.path.relpath(os.path.dirname(file_path), lib_dir).replace('\\', '/')

    for line in lines:
        match = re.search(r"import\s+['\"](.+?)['\"];", line)
        if match:
            imp_path = match.group(1)
            
            # Skip non-project imports
            if imp_path.startswith('package:flutter/') or imp_path.startswith('package:provider/') or imp_path.startswith('package:dio/') or imp_path.startswith('dart:'):
                new_lines.append(line)
                continue
            
            # If it's a package import but uses wrong package name (if any)
            # Or if it's a package import for our project, let's verify it
            if imp_path.startswith(f'package:{package_name}/'):
                # Verify if it exists
                internal_path = imp_path.replace(f'package:{package_name}/', '')
                if not os.path.exists(os.path.join(lib_dir, internal_path.replace('/', os.sep))):
                    # Try to find the file by name
                    filename = imp_path.split('/')[-1]
                    if filename in file_map:
                        new_imp = f"package:{package_name}/{file_map[filename]}"
                        line = line.replace(imp_path, new_imp)
                        changed = True
                new_lines.append(line)
                continue

            # Handle relative imports
            if imp_path.startswith('.') or not imp_path.startswith('package:'):
                # Try to resolve relative path
                abs_imp_path = os.path.normpath(os.path.join(os.path.dirname(file_path), imp_path.replace('/', os.sep)))
                if not os.path.exists(abs_imp_path) and not abs_imp_path.endswith('.dart') and os.path.exists(abs_imp_path + '.dart'):
                    abs_imp_path += '.dart'
                
                if not os.path.exists(abs_imp_path):
                    # Broken relative import! Try to find the file
                    filename = imp_path.split('/')[-1]
                    if not filename.endswith('.dart'):
                        filename += '.dart'
                    
                    if filename in file_map:
                        new_imp = f"package:{package_name}/{file_map[filename]}"
                        line = line.replace(imp_path, new_imp)
                        changed = True
                    else:
                        # Could be a folder import or something else, leave it for now
                        pass
                else:
                    # It exists, but let's convert to package import anyway for consistency
                    rel_to_lib = os.path.relpath(abs_imp_path, lib_dir).replace('\\', '/')
                    new_imp = f"package:{package_name}/{rel_to_lib}"
                    line = line.replace(imp_path, new_imp)
                    changed = True
            
            new_lines.append(line)
        else:
            new_lines.append(line)

    if changed:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        return True
    return False

count = 0
for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            if fix_imports(os.path.join(root, file)):
                count += 1

print(f"Fixed imports in {count} files.")
