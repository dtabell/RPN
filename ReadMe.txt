====================================================================
===  R E A D M E  for RPN: a Reverse Polish Notation calculator  ===
====================================================================

Description
-----------

Yet another RPN calculator ...

This project defines an RPN (reverse Polish notation) calculator.
It includes various pre-defined mathematical and physical constants
and functions, and it includes a simple facility for defining your
own constants and functions. It also allows you to load your own
definitions from external files.

This calculator, written in Perl, implements a simple, command-line
interface that includes readline support. If your system has one of
the various ReadLine implementations (Term::ReadLine::*) installed,
then the readline support should 'just work'. This has been tested
with Term::ReadLine::Gnu and Term::ReadLine::Perl5.

The executable command (i.e. the installed script) is 'rpn'.  For
help, type 'help', '?', or '??' at the RPN prompt.


Installation
------------

Installing RPN should be about as simple as running

  installRPN.sh

from the directory containing this ReadMe file. By default, that
script will install the executable in ~/bin/, and will install
other files in ~/.rpn/. Use the command-line arguments -b and -l
to modify those paths. Use -H for a full help message.


ReadLine Support
----------------

If one of the Term::ReadLine::* packages is not already installed,
and you do not have administrative privileges on your machine, you
can install one of those packages for local use. In this case, you
must add the -L flag during installation (i.e. 'installRPN.sh -L').

To create a local install of Perl modules, the following series of
steps is one recommended procedure:

  wget -O- http://cpanmin.us | perl - -l ~/perl5 App::cpanminus

This command fetches the latest version of cpanm and prints it to
STDOUT, which output is then piped to a perl command. The first -
tells perl to expect the program to come in on STDIN, and makes
perl run the version of cpanm we just downloaded. Perl passes the
remaining arguments to cpanm. The -l ~/perl5 argument tells cpanm
where to install Perl modules, and the remaining argument is the
module to install. App::cpanminus is a package that installs cpanm.
Here, and in what follows, replace ~/perl5 with, say, ~/apps/perl5,
or whatever other name you wish to use for the directory in which
to store your local perl modules.

  export PATH=~/perl5/bin:$PATH

This command makes sure the shell can find the newly installed
version of cpanm. Also add this command, or its equivalent, to
your ~/.bashrc file.

  cpanm --force -l ~/perl5 local::lib

This command installs local::lib, a helper Perl module that manages
the environment variables needed to run Perl modules installed in
a local directory. The --force flag forces installation even if
some tests fail. (In my case one test, of many, failed.)

  eval `perl -I ~/perl5/lib/perl5 -Mlocal::lib=~/perl5`

This command sets environment variables needed to use local modules.

  echo 'eval `perl -I ~/perl5/lib/perl5 -Mlocal::lib=~/perl5`' >> ~/.bashrc

This command repeats the previous one, but appends the output to
~/.bashrc, to ensure that those environment variables are defined
the next time we log in.

  echo 'export MANPATH=$HOME/perl5/man:$MANPATH' >> ~/.bashrc

This command makes it possible for man to find the man pages for
your local Perl modules.

  cpanm Term::ReadLine::Gnu

This last command installs the Perl module Term::ReadLine::Gnu in
your newly created space for local modules.

If your system has more than one of the Term::ReadLine::* modules
installed, you can set the environment variable PERL_RL to tell
Term::ReadLine which one you prefer. For example, add

  export PERL_RL='Gnu'

or

  export PERL_RL='Perl5'

to your ~/.bashrc file. In addition, you can set the default mode
for editing by adding, for example, the line

  set editing-mode vim

to your ~/.inputrc file.


History
-------

I wrote the original version of RPN back in February of 2001 as a
"Learn Some Perl" project. I particularly wanted to include the
ability to define, or pre-define, variables and mathematical and
physical constants (e.g. e, pi, c, etc.) as well as the ability
to define simple 'programs'.

Feb 2001: original code
Sep 2008: inverse hyperbolc functions
Mar 2011: readline support
May 2011: parse times (angles) from hh::mm:ss.sss to (h/d).ms form,
          and add and subtract times (angles) in (h/d).ms form
Nov 2015: parse numbers with any of the standard SI prefixes
Nov 2015: history is now saved between sessions
Nov 2015: wrote an install script, and put up on GitHub, because
          I grew tired of the "tar, scp, untar, and mv" sequence
          every time I introduced a new feature


Future Work and Feature Requests
--------------------------------
 * when reading external files, assume a .rpn extension
 * modify option -e to delete the stack index from output
 * implement option -f for reading commands from a file
 * init_* methods should return 0/1, and be acted upon accordingly
 * modify function_def() so that definitions appear in the history
 * control flow logic
 * random number generation
 * complex numbers
 * use File::Find to find rpn- and user-written files robustly
 * check user-defined quantities against native abbreviations
 * array operations
 * fix the space formatting of the rpn script
 * tolerant comparisons (??)
 * implement tests
 * rpnrc to implement/save user preferences (?)


Author
------
Dan T. Abell
ironphoton69@gmail.com

