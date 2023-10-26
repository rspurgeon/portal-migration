#!/usr/bin/env python3

import yaml
import sys
import os
import base64
import json

# Mapping from source to target fields
COLOR_MAPPINGS = {
    "header": "section.header",
    "page": "section.body",
    "hero": "section.hero",
    "accent": "section.accent",
    "tertiary": "section.tertiary",
    "stroke": "section.stroke",
    "footer": "section.footer",
    "text_hero": "text.hero",
    "text_primary": "text.primary",
    "text_secondary": "text.secondary",
    "text_headings": "text.headings",
    "text_links": "text.link",
    "button_primary_fill": "button.primary_fill",
    "button_primary_text": "button.primary_text"
}

DEFAULT_VALUES = {
    "custom_theme": {
        "colors": {
            "section": {
                "header": {
                    "value": "#F8F8F8",
                    "description": "Background for header"
                },
                "body": {
                    "value": "#FFFFFF",
                    "description": "Background for main content"
                },
                "hero": {
                    "value": "#F8F8F8",
                    "description": "Background for hero section"
                },
                "accent": {
                    "value": "#F8F8F8",
                    "description": "Subtle background"
                },
                "tertiary": {
                    "value": "#FFFFFF",
                    "description": "Tertiary background"
                },
                "stroke": {
                    "value": "rgba(0,0,0,0.1)",
                    "description": "Border color"
                },
                "footer": {
                    "value": "#07A88D",
                    "description": "Background for footer"
                }
            },
            "text": {
                "header": {
                    "value": "rgba(0,0,0,0.8)",
                    "description": "Header text"
                },
                "hero": {
                    "value": "#FFFFFF",
                    "description": "Hero text"
                },
                "headings": {
                    "value": "rgba(0,0,0,0.8)",
                    "description": "Headings text"
                },
                "primary": {
                    "value": "rgba(0,0,0,0.8)",
                    "description": "Main content text"
                },
                "secondary": {
                    "value": "rgba(0,0,0,0.8)",
                    "description": "Supporting text"
                },
                "accent": {
                    "value": "#07A88D",
                    "description": "Subtle text"
                },
                "link": {
                    "value": "#07A88D",
                    "description": "Link text"
                },
                "footer": {
                    "value": "#FFFFFF",
                    "description": "Footer text"
                }
            },
            "button": {
                "primary_fill": {
                    "value": "#1155CB",
                    "description": "Background for Primary Button"
                },
                "primary_text": {
                    "value": "#FFFFFF",
                    "description": "Text for Primary Button"
                }
            }
        }
    },
    "text": {
        "catalog": {
            "welcome_message": "Welcome to our platform!",
            "primary_header": "Discover our content"
        }
    }
}

def deep_set(dct, keys, value):
    for key in keys[:-1]:
        dct = dct.setdefault(key, {})
    dct[keys[-1]] = value

def process_colors(source_data, target_data):
    for src_key, target_path in COLOR_MAPPINGS.items():
        if src_key in source_data['colors']:
            deep_set(target_data, ["custom_theme", "colors"] + target_path.split('.'), source_data['colors'][src_key])

def process_fonts(source_data, target_data):
    if 'fonts' in source_data:
        target_data['custom_fonts'] = source_data['fonts']

def process_images(base_dir, source_data, target_data):
    if 'images' in source_data:
        target_data['images'] = {}
        for image_key, image_path in source_data['images'].items():
            with open(os.path.join(base_dir, image_path), "rb") as image_file:
                encoded_string = base64.b64encode(image_file.read()).decode('utf-8')
                target_data['images'][image_key] = {
                    "data": f"data:image/{image_path.split('.')[-1]};base64,{encoded_string}",
                    "filename": os.path.basename(image_path)
                }

def main():
    base_dir = sys.argv[1]

    with open(os.path.join(base_dir, 'theme.conf.yaml'), 'r') as file:
        source_data = yaml.safe_load(file)

    target_data = DEFAULT_VALUES.copy()

    process_colors(source_data, target_data)
    process_fonts(source_data, target_data)
    process_images(base_dir, source_data, target_data)

    print(json.dumps(target_data, indent=2))

if __name__ == "__main__":
    main()
