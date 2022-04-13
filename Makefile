###############################################################################
# Makefile for project lastcopy
# Created: 2021-11-22
# Copyright (c) Edmonton Public Library 2021
# The Edmonton Public Library respectfully acknowledges that we sit on
# Treaty 6 territory, traditional lands of First Nations and Metis people.
#
# Manages distribution of scripts to appropriate servers as required.
#
#    Copyright (C) 2022  Andrew Nisbet, Edmonton Public Library
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
PRODUCTION_ILS=edpl.sirsidynix.net
TEST_ILS=edpltest.sirsidynix.net
USER=sirsi
SERVER=ils@epl-ils.epl.ca
# REMOTE=~/Unicorn/EPLwork/anisbet/Discards/Test
REMOTE=/software/EDPL/Unicorn/Bincustom
APP_DIR=/software/EDPL/Unicorn/EPLwork/cronjobscripts/LastCopy
LOCAL=~/projects/lastcopy
APPS=lastcopy.sh grubby.sh series.sh
DRIVER=lastcopy_driver.sh items.awk titles.awk series.awk Readme.md

test: 
	scp ${APPS} ${USER}@${TEST_ILS}:${REMOTE}
	scp Readme.md lastcopy_compiler.sh ${USER}@${TEST_ILS}:${APP_DIR}
	
production: 
	scp ${APPS} ${USER}@${PRODUCTION_ILS}:${REMOTE}
	scp Readme.md lastcopy_compiler.sh ${USER}@${PRODUCTION_ILS}:${APP_DIR}
	scp ${DRIVER} ils@epl-ils.epl.ca:/home/ils/last_copy/bin
