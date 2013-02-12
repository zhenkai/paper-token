# Informational Token System for Paper Writing
==============================================

Sometimes in paper writing, it is desired to know who is working on which sections. You can always ask in person or by email, but sometimes you wish you could just check the paper repo and figure out.

This script, "token", is design for such purpose. However, do note that it is informational and advisory only. No enforcement at all, i.e. you can always modify a file even without a token, which is in git's DNA. But assume every author of the paper follows the protocol, then one can have a quick glance and figure out whether it is ok to work on a specific section.

##Use "token"
To use "token", simply copy "token" into the working directory of our paper repo. By default, it cares only about ".tex" files. You can tweak the script a little bit if you want to add tokens for other files.
`$ ./token` would show you how to use.
