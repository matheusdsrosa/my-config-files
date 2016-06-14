source $HOME/.bash_aliases
# pyenv
if which pyenv > /dev/null; then eval "$(pyenv init -)"; fi

# virtualenv wrapper
export WORKON_HOME=$HOME/.virtualenvs
export PROJECT_HOME=$HOME/Projects
source /usr/local/bin/virtualenvwrapper.sh

# pip runs only on a virtualenv
export PIP_REQUIRE_VIRTUALENV="true"

# global pip

function gpip()
{
   PIP_REQUIRE_VIRTUALENV="" pip "$@"
}

function gpip3()
{
  PIP_REQUIRE_VIRTUALENV="" pip3 "$@"
}
