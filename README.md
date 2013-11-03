BuildServ
=========
[SpringRTS](http://springrts.com/) lobby bot implementing an automated build
service for the engine through lobby commands.

BuildServ development was initially motivated by a problem with official
buildbot infrastructure which lead to a long downtime period, during which no
dev build was available. At first, BuildServ was only a very basic bot which
could only rebuild and upload main Spring binary through a single !rebuild
command in lobby, as described in this [forum post](http://springrts.com/phpbb/viewtopic.php?p=267872#p267872).
Then, it progressively evolved from this temporary basic build system to a more
advanced cross-compiling service offering more and more functionalities such
as:
- full VCS integration (to build specific branches/tags/revisions, check commit
history...)
- installer builds
- debug symbols generation
- automated stacktrace translating
- multi-toolchain (mingw32, native GCC, specific cross-compilers...)
- multi-target system (Windows, Windows64, Linux...)
- multi-VCS (Subversion and GIT)
- integration with GitHub
- user-defined compilation profiles with sets of compile flags

It has been used to generate official Spring binaries and installation packages
from version 0.77b2 to 0.81.2.1 (from March 2008 to March 2010), and was
finally shut down in February 2011 (as no stacktrace needed to be translated by
it anymore).

Dependencies
------------
The BuildServ application depends on following projects:
* [SimpleLog](https://github.com/Yaribz/SimpleLog)
* [SpringLobbyInterface](https://github.com/Yaribz/SpringLobbyInterface)

The BuildServ application is based on the templates provided by following
project:
* [SpringLobbyBot](https://github.com/Yaribz/SpringLobbyBot)

Licensing
---------
Please see the file called [LICENSE](LICENSE).

Author
------
Yann Riou <yaribzh@gmail.com>