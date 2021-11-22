###############################################################################
# Makefile for project lastcopy
# Created: 2021-11-22
# Copyright (c) Edmonton Public Library 2021
# The Edmonton Public Library respectfully acknowledges that we sit on
# Treaty 6 territory, traditional lands of First Nations and Metis people.
#
# < Script description here >
#    Copyright (C) 2021  Andrew Nisbet, Edmonton Public Library
# The Edmonton Public Library respectfully acknowledges that we sit on
# Treaty 6 territory, traditional lands of First Nations and Metis people.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
#      0.0 - Dev.
###############################################################################
# Change comment below for appropriate server.
PRODUCTION_SERVER=edpl.sirsidynix.net
TEST_SERVER=edpltest.sirsidynix.net
USER=sirsi
REMOTE=~/Unicorn/EPLwork/anisbet/
LOCAL=~/projects/lastcopy/
APP=lastcopy.sh

test:
	scp ${LOCAL}${APP} ${USER}@${TEST_SERVER}:${REMOTE}
production: test
	scp ${LOCAL}${APP} ${USER}@${PRODUCTION_SERVER}:${REMOTE}

