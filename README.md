# updateMagentoPatches

## Project details

The Magento's patches patch only the default Magento source code and so, does not take care of your own customisation.

If you have create a customisation for your website based on a vulnerable files, even if you apply the PATCH file, you are still vulnerable.

This shell script ensure to apply also patches instructions on the local overload you made.

## Requirements

* Bash
* init-functions lib
* A Magento patch file
* realpath

## TODO

### If overload have been made using a symlink, it is not patched

### Manage PHP files overload by configuration

For now, this shell script file check the PHP files which have been overloaded using the autoloading process.
 We must also patch the files which have been overloaded by configuration (config.xml files)
 
### Manage templates which have been overloaded using layout setTemplate syntax

For now,this shell script file check the PHTML files which have been overloaded in a package and theme using the same template path.
 We must also patch custom template files which have been loaded using layout setTemplate syntax.

### Manage templates which have been overloaded using blocks setTemplate syntax

For now, this shell script file check the phtml files which have been overloaded in a package and theme using the same template path. 
We must also patch the custom template files which have been loaded using the block setTemplate syntax.

## Install

No requirement. 

## Usage

updateMagentoPatch.sh %Magento_Patch_File_To_Update%

## Support contact

If you have problems please have patience, as normal support is done during free time.
If you are willing to pay to get your problem fixed, communicate this from the start to get faster responses.





