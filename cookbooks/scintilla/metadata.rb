name             'scintilla'
maintainer       'Scintilla'
maintainer_email 'cdelguercio@gmail.com'
license          'All rights reserved'
description      'Installs/Configures scintilla'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.1'

depends "build-essential"
depends "apt"
depends "git"
depends "poise-python"
depends "supervisor"
depends "nginx"

recipe "scintilla", "Installs software for webapps"
recipe "scintilla::deploy", "Deploys all code bases"
recipe "scintilla::nginx", "Deploys ubuntu server"
recipe "scintilla::packages", "Installs packages for codebase"

supports "ubuntu"
