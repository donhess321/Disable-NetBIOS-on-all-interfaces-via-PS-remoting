# Disable-NetBIOS-on-all-interfaces-via-PS-remoting

This will disable NetBIOS on all interfaces over a PS remote session.  It can also be run locally when the local computer name is input.  This makes it usable as a startup script.  If no computer name is input an attempt is made to get all the computers in the domain and run against them.  An event is logged to the System log so changes can be tracked.

This is a reposting from my Microsoft Technet Gallery.
