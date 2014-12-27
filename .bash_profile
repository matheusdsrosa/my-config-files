source ~/.bash_prompt
source ~/.bash_aliases

export GREP_OPTIONS="--color=auto"
export GREP_COLOR="4;33"
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagad
alias list="ls -Gh"
alias wkhtmltopdf="/etc/wkhtmltopdf/bin/wkhtmltopdf"

# for mysql
PATH=$PATH:/usr/local/mysql/bin/
export DYLD_LIBRARY_PATH=/usr/local/mysql/lib

### Added by the Heroku Toolbelt
PATH="/usr/local/heroku/bin:$PATH"

PATH=$PATH:/Library/PostgreSQL/9.3/bin/

# Setting PATH for Python 3.4
# The orginal version is saved in .bash_profile.pysave
PATH="/Library/Frameworks/Python.framework/Versions/3.4/bin:$PATH"

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

export WORKON_HOME=$HOME/Virtualenvs
export PROJECT_HOME=$HOME/Projects

source /usr/local/bin/virtualenvwrapper.sh

PATH=/usr/local/bin:/usr/local/sbin:$PATH
if [ -d /usr/local/lib/python2.7/site-packages ]; then
    export PYTHONPATH=/usr/local/lib/python2.7/site-packages:$PYTHONPATH
fi
export PATH
