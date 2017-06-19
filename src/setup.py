from setuptools import setup, find_packages

setup(
    name                  = "todobackend",
    version               = "0.1.0",
    description           = "Backend REST service",
    packages              = find_packages(),
    include_packages_data = True,
    scripts               = ["manage.py"],
    install_requires      = ["Django>=1.10,<2.0",
                             "django-cors-headers>=2.0.2",
                             "djangorestframework>=3.6.2",
                             #"mysql-connector>=2.1.4",
                             #"mysqlclient>=1.3.10"],
                             "MySQL-python>=1.2.5"],
    extras_require        = {
                                "test": [
                                    "colorama>=0.3.9",
                                    "coverage>=4.4.1",
                                    "django-nose>=1.4.4",
                                    "nose>=1.3.7",
                                    "pinocchio>=0.4.2"
                                ]
                             }
)
# https://caremad.io/posts/2013/07/setup-vs-requirement/
