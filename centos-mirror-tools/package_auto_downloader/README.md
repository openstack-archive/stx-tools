# Package Auto Search and Download

This program will search in Google for an rpm package and attempt to download it.

### How to use it

* Create a Virtual Environment (highly recommended but optional)
  - `$ virtualenv -p python3 .venv`
  - To activate the virtual environment run `$ source .venv/bin/activate`
  - Once you are done defaultactivate it by running `$ deactivate`

- Install the requirements by running `$ pip install -r requirements.txt`

- Run the script `python3 package_search.py -p package1 [package2 ...] [-n N]`
  - packageX: full name of the rpm package you are looking for, you can send a space separated list of packages
  - N: number of Google pages to look into, if this argument is not provided, default is 10
  _- A help message can be seen by using the `-h` option_

The program will create a directory called `downloads` and subdirectories with the name of the packages, each subdirectory will contain a set of packages with indexes in the way of XX-pack1.rpm, XX represents a consecutive number.
