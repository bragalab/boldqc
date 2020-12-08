from setuptools import setup, find_packages

setup(name="boldqc2",
      description="boldqc2",
      author="Neuroinformatics Research Group",
      author_email="support@neuroinfo.org",
      packages=find_packages(),
      url="http://neuroinformatics.harvard.edu/",
      scripts=['bin/extqc.py'],
      install_requires=[
          "nibabel", 
          "pylib"
      ]
)

