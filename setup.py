from setuptools import setup, find_packages
from pathlib import Path

# Leer el README.md como descripción larga
this_dir = Path(__file__).parent
long_description = (this_dir / "README.md").read_text(encoding="utf-8")

setup(
    name="enable-littlefs",
    version="1.0.0",
    description="ESP-IDF utility for generating VSCode tasks and LittleFS support",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="PoleG97",
    packages=find_packages(),
    include_package_data=True,
    entry_points={
        'console_scripts': [
            'enable-littlefs = littlefscli.enable_littlefs:main'
        ]
    },
    package_data={
        'littlefscli': ['templates/*.json']
    },
    classifiers=[
        "Programming Language :: Python :: 3",
        "Operating System :: OS Independent",
    ],
    python_requires='>=3.6',
)
