#!/usr/bin/env python3
import re

# Read the file
with open('/Users/gurindersingh/Documents/Developer/Swift-CMS/Sources/CMSAdmin/AdminController.swift', 'r') as f:
    content = f.read()

# Pattern to match \(TEXT) and replace with (TEXT)
pattern = r'\\\(([a-zA-Z_][a-zA-Z0-9_.]*)\\\)'
replacement = r'(\1)'

# Apply the replacement
content1 = re.sub(pattern, replacement, content)

# Write back
with open('/Users/gurindersingh/Documents/Developer/Swift-CMS/Sources/CMSAdmin/AdminController.swift', 'w') as f:
    f.write(content1)

print("Fixed escaping issues")
