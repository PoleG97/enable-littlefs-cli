from setuptools import setup, find_packages

setup(
    name="enable-littlefs",
    version="1.0.0",
    description="ESP-IDF utility for generating VSCode tasks and LittleFS support",
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
