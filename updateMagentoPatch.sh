#!/bin/bash
###########################################################################################################
#
# The Magento patch files available from magentocommerce website patches only the core files and the default theme files.
#
# if you previously overloaded a file which need to be patched, your overload won't be patched and so, you are still vulnuérable
#
# this shell script:
# - create a copy of patch file
# - Browse for each patch instruction if there is an overload. If yes, it will add the appropriate patch instruction in the generated copy.
#
# This script does not take care for now:
# - Of the overloads made using configuration.
# - Of the custom templates loaded either in source code or in layouts
#
# @autnor Matthieu MARY
#
###########################################################################################################
LIB_FILE="/lib/lsb/init-functions"
. $LIB_FILE
#
# Method which display syntax
#
syntax () {
	echo "Usage: $0 %MagentoPatchFile%";
}

PATCH=$1
# check if specified patch file exists
if [ ! -f "$PATCH" ]; then
	echo "Invalid patch file $1";
	syntax
	exit 1
fi

SOURCE_PATH[0]="lib";
SOURCE_PATH[1]="app/code/core";
SOURCE_PATH[2]="app/code/community";
SOURCE_PATH[3]="app/code/local";
DEST_PATH[0]="app/code/core";
DEST_PATH[1]="app/code/community";
DEST_PATH[2]="app/code/local";
TMP_PATCH_FILE="/tmp/patch_content";
# 
# find the next overload file path

# for example, if you wants to find next path for 
# - lib/Zend/Cache/Core.php, it'll retrieve app/code/core/Zend/Cache/Core.php
# - app/code/core/Mage/Core/Model/Config.php, it'll retrieve  app/code/community/Mage/Core/Model/Config.php
# USAGE: findNxtPath path_to_file
#
findNxtPath () {
	SOURCE=$1;
	START=0;
	DEST="";
	for index in ${!DEST_PATH[@]}; do
		# find which kind of file we have here: core / community / lib ?
		PATTERN=${SOURCE_PATH[index]};
		FIND=$(echo "$SOURCE" | grep "$PATTERN");
		if [ ! -z "$FIND" ]; then
			CURRENT_POS=$index;
		fi
	done;
	PATTERN=${DEST_PATH[$CURRENT_POS]};
	OLD_PATTERN=${SOURCE_PATH[$CURRENT_POS]};
	DEST=$(echo "$SOURCE" | sed "s|$OLD_PATTERN|$PATTERN|g");
	echo $DEST;
}
# create temp file name which contains updated patchs files
NEWPATCH=`echo $PATCH | sed "s/.sh/-updated.sh/g"`
NEWPATCHFP="/tmp/$NEWPATCH"
log_begin_msg "Copy original patch file $PATCH to $NEWPATCH";
cp $PATCH $NEWPATCHFP
log_end_msg $?
###################
#
# process PHP files
#
###################
for i in `cat $PATCH | grep "diff --git" | grep ".php" | cut -d " " -f 3`; do
	log_begin_msg "Processing PHP file to patch $i";
	# 
	# check possibles existing overload:
	# Magento patch only core files, default templates files and lib files.
	# If they have been overloaded, patch will be applied only on core files and so... will be still vulnerable!
	# 
	# first check which kind of files Magento patch wants to patch
	#
	CURRENT_POS=1;
	FIND=-1;
	#
	# 1. Processing files which have been overloaded by autoload
	# 
	for index in ${!SOURCE_PATH[@]}; do
		# find which kind of file we have here: core / community / lib ?
		PATTERN=${SOURCE_PATH[index]};
		FIND=$(echo "$i" | grep "$PATTERN");
		if [ ! -z "$FIND" ]; then
			CURRENT_POS=$index;
		fi
	done;
	# with this index, we are able to browse all possible local overloads
	MAXOVERLOAD=${#DEST_PATH[@]};
	FILE_TO_PATCH=$i;
	OVERLOADED=1;
	for (( c=$CURRENT_POS; ((c<=$MAXOVERLOAD) && (OVERLOADED=1)); c++ )); do
		OVERLOAD_FILE=$(findNxtPath $FILE_TO_PATCH);
		if [ -f "$OVERLOAD_FILE" ] && [ "$OVERLOAD_FILE" != "$FILE_TO_PATCH" ]; then
			FILE_TO_PATCH=$OVERLOAD_FILE;
			# ok, we have a second file to patch.
			#
			# we generate the patch instruction for this new file to patch
			#
			# load the patch instruction from the original patch file
			FILE_PATTERN=$(echo "$i" | sed "s|\\/|\\\/|g");
			# extract the patch instruction and save it in $TMP_PATCH_FILE
			awk "/diff --git/{found=0} {if(found) print} /diff --git $FILE_PATTERN $FILE_PATTERN/{found=1}" $PATCH > $TMP_PATCH_FILE;
			# remplace in this instruction the original filepath with the overloaded one and add it in $NEWPATCH
			echo "diff --git $OVERLOAD_FILE $OVERLOAD_FILE"  >> $NEWPATCHFP
			cat $TMP_PATCH_FILE | sed "s|$i|$OVERLOAD_FILE|g" >> $NEWPATCHFP
			log_warning_msg "This file have been overloaded by $OVERLOAD_FILE. Patch for this overload have been added";
		else
			OVERLOADED=0;	
		fi
		FILE_TO_PATCH=$OVERLOAD_FILE;
	done 	
	log_end_msg 0
done;
#################################################
#
# process template files (.phtml)
#
#################################################
PHTML=`cat $PATCH | grep "diff --git" | grep ".phtml" | wc -l`;
if [ $PHTML -gt 0 ]; then
	for i in `cat $PATCH | grep "diff --git" | grep ".phtml" | cut -d " " -f 3`; do
		log_begin_msg "Processing template file $i";
		echo "$i" | grep "frontend" > /dev/null;
		SCOPE="frontend";
		if [ $? -eq 0 ]; then
			TEMPLATE_BASE_PATH=`echo "$i" | sed "s|app/design/frontend/base/default||g"`;
		else		
			SCOPE="adminhtml";
			TEMPLATE_BASE_PATH=`echo "$i" | sed "s|app/design/adminhtml/base/default||g"`;
			TEMPLATE_BASE_PATH=`echo "$TEMPLATE_BASE_PATH" | sed "s|app/design/adminhtml/default/default||g"`;
		fi
		for j in `find . -name "*.phtml" -type f | grep $SCOPE | grep $TEMPLATE_BASE_PATH`; do 
			# exclude current file to patch
			if [ $(realpath $i) != $(realpath $j) ]; then
				# look for the file to patch in the original patch file: some Patchs contains references to some themes
				P=`echo "$j" | sed "s|\./||g"`;
				grep "$P" "$PATCH" > /dev/null;
				if [ $? -eq 1 ]; then
					FILE_PATTERN=$(echo "$i" | sed "s|\\/|\\\/|g");
					# extract the patch instruction and save it in $TMP_PATCH_FILE
					awk "/diff --git/{found=0} {if(found) print} /diff --git $FILE_PATTERN $FILE_PATTERN/{found=1}" $PATCH > $TMP_PATCH_FILE;
					# remplace in this instruction the original filepath with the overloaded one and add it in $NEWPATCH
					echo "diff --git $j $j"  >> $NEWPATCHFP
					cat $TMP_PATCH_FILE | sed "s|$i|$j|g" >> $NEWPATCHFP
					log_warning_msg "This template have been customized by $j. Patch for this custom theme have been added";	
				else
					log_warning_msg "This template have been customized by $j but there is a patch instruction in the original patch file. Skip custom patch";
				fi		
			fi;
		done;
		log_end_msg 0
	done;
fi;
#################################################
#
# process layout files (.xml)
#
#################################################
PHTML=`cat $PATCH | grep "diff --git" | grep ".xml" | grep "design" | wc -l`;
if [ $PHTML -gt 0 ]; then
	for i in `cat $PATCH | grep "diff --git" | grep ".xml" | grep "design" | cut -d " " -f 3`; do
		log_begin_msg "Processing layout file $i";
		echo "$i" | grep "frontend" > /dev/null;
		SCOPE="frontend";
		if [ $? -eq 0 ]; then
			TEMPLATE_BASE_PATH=`echo "$i" | sed "s|app/design/frontend/base/default||g"`;
		else		
			SCOPE="adminhtml";
			TEMPLATE_BASE_PATH=`echo "$i" | sed "s|app/design/adminhtml/base/default||g"`;
			TEMPLATE_BASE_PATH=`echo "$TEMPLATE_BASE_PATH" | sed "s|app/design/adminhtml/default/default||g"`;
		fi		
		for j in `find . -name "*.xml" -type f | grep $SCOPE | grep $TEMPLATE_BASE_PATH`; do 
			# exclude current file to patch
			if [ $(realpath $i) != $(realpath $j) ]; then
				# look for the file to patch in the original patch file: some Patchs contains references to some themes
				P=`echo "$j" | sed "s|\./||g"`;
				grep "$P" "$PATCH" > /dev/null;
				if [ $? -eq 1 ]; then
					FILE_PATTERN=$(echo "$i" | sed "s|\\/|\\\/|g");
					# extract the patch instruction and save it in $TMP_PATCH_FILE
					awk "/diff --git/{found=0} {if(found) print} /diff --git $FILE_PATTERN $FILE_PATTERN/{found=1}" $PATCH > $TMP_PATCH_FILE;
					# remplace in this instruction the original filepath with the overloaded one and add it in $NEWPATCH
					echo "diff --git $j $j"  >> $NEWPATCHFP
					cat $TMP_PATCH_FILE | sed "s|$i|$j|g" >> $NEWPATCHFP
					log_warning_msg "This layout have been customized by $j. Patch for this custom theme have been added";	
				else
					log_warning_msg "This layout have been customized by $j but there is a patch instruction in the original patch file. Skip custom patch";
				fi			
			fi;
		done;
		log_end_msg 0
	done;
fi;
###################################################
# a little warning
###################################################
log_begin_msg "validating if list of files to be patched is complete"
log_warning_msg "This shell script have processed only the PHP files overloaded using include_path, or themes (phtml, and layouts) files which have been copied from default theme.. It does not manage configuration overload or custom template management. You should inspect deeply your code source to ensure that all files are really patched"
log_end_msg 0

chmod +x $NEWPATCHFP
cp $NEWPATCHFP .
