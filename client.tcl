#############
# Lost Msg Client
#############
#Tk Ttk 
foreach pkg {tls} {
	package require $pkg
}


package provide LostMC 0.1

namespace eval LostMC {
	variable server
	variable files

	proc Connect {host port} {
		variable server
		set server [tls::socket $host $port]
		fconfigure $server -buffering line -blocking 0
		fileevent $server readable [list [namespace current]::FromServer $server]
		puts $server "c"
		return $server
	}
	proc FromServer {sock} {
		if {[eof $sock] || [catch {gets $sock line}]} {
			puts "Server just quit!"
			close $sock
		} else {
			[namespace current]::CommandSwitch  $sock $line
		}
	}
}
#Switch Server to Client protocol numbers(or commands)
proc ::LostMC::CommandSwitch {sock msg} {
	switch -- [lindex $msg 0] {
		c 	{ puts [lrange $msg 1 end] }
		0 	{ puts "Not enough data for command..:  $msg "  }
		1 	{ puts "please auth" }
		2 	{ puts "auth ok " }
		3 	{ puts "Inexistent Username " }
		4 	{ puts "auth not ok wrong password " }
		5 	{ puts "Username already exists " }
		6 	{ puts "Username registered " }
		7 	{ puts "Message From [join [lrange $msg 1 end]] " } 
		8 	{ ::LostMC::FileHandling $sock 1 [lrange $msg 1 end] }
		9 	{ ::LostMC::FileHandling $sock 2 [lrange $msg 1 end] }
		10 	{ ::LostMC::FileHandling $sock 3 [lrange $msg 1 end] }
		11 	{ puts "<username> wants to be your friend " }
		12	{ puts "<username> accepted your friendship " }
		13	{ puts "<username> rejected your friendship " }
		14 	{ ::LostMC::OfflineMsg [lrange $msg 1 end] }
		15 	{ puts "You have been logged out because someone else logged in on another computer. " }
		16 	{ puts "You have been kicked from the server by an Admin with the reason: [lrange $msg 1 end] " }
		default { puts "New cmd?: $msg" }
	}
}
proc ::LostMC::OfflineMsg {msg} {
	puts "You have offline messages"
	foreach {msgTime from message} $msg {
		puts "([clock format $msgTime -format {%d-%m-%Y %H:%M:%S}]) ${from}: [join $message]"
	}
}
proc ::LostMC::Register {username password email} {
	variable server
	puts $server "2 $username $password $email"
}
proc ::LostMC::Auth {username password} {
	variable server
	puts $server "1 $username $password"
}
proc ::LostMC::Msg {username msg} {
	variable server
	puts $server "3 $username [list $msg]"
}

#############
# File sending 
#############
proc ::LostMC::FileHandling {} {
		Client to Server
		5	Send file: <username> <filename> <size>
		6	Accept file from user... <username> <uniqueFileID> <- Opened sock and ready for the file
		7 	Reject file from user: <username> <uniqueFileID> <- no thanks

		Server to client
		8 	Someone wants to send you a file <username> <file> <size> <uniqueFileID>
		9 	User is ready  to get file: <username> <uniqueFileID> <UsernameIp>
		10 	Username rejected file transfer: <username> <uniqueFileID>

	switch -- $type {
		1 { puts $otherUserSock "8 $yourUser [lrange $msg 1 end] [generateCode 13]" }
		2 { puts $otherUserSock "9 $yourUser [lindex $msg 1]" }
		3 { puts $otherUserSock "10 $yourUser [lindex $msg 1]" }
	}
}

#############
#User Interface
#############

#First Screen
proc ::LostMC::DrawFirstScreen {} {
	#Make the first GUI that big and position it relative to the right bottom corner:) (-).. or left top (+)
	wm geometry . 400x600-50-100
	ttk::labelframe .frmLogin -text "Login"
	
	ttk::label .lblUsername -text "Username: "
	ttk::label .lblPassword -text "Password: "
	ttk::entry .txtUsername  -width 20 -textvariable username
	ttk::entry .txtPassword -width 20 -textvariable password -show *
	#ttk::button 
	grid .frmLogin 
	grid .lblUsername .txtUsername -in  .frmLogin
	grid .lblPassword .txtPassword -in  .frmLogin
}
#Login Screen
proc ::LostMC::DrawLogin {} {
	
	
}
#Register Screen
proc ::LostMC::DrawRegister {} {
	
	
}

#Buddy List
proc ::LostMC::DrawBuddyList {} {
	
	
}
#Chat Screen (user for private messages, group chats and other thigs)
proc ::LostMC::DrawPrivateMsg {} {
	
	
}
#############
#Random functions
#############
proc unixtime {} {
	return [clock seconds]
}
proc rnd {min max} {
	expr {int(($max - $min + 1) * rand()) + $min}
}

proc generateCode {length {type 1}} {
	if {$type == 1} {
		set string "azertyuiopqsdfghjklmwxcvbnAZERTYUIOPQSDFGHJKLMWXCVBN0123456789"
	} elseif {$type == 2} { set string AZERTYUIOPQSDFGHJKLMWXCVBN0123456789 
	} elseif {$type == 3} { set string azertyuiopqsdfghjklmwxcvbn0123456789 } else {  set string 0123456789 }
	set code ""
	set stringlength [expr {[string length $string]-1}]
	for {set i 0} {$i<$length} {incr i} {
		append code [string index $string [rnd 0 $stringlength]]
	}
	return $code
}

if {0} {

set maxClients 0;# 13333
for {set i 0} {$i<=$maxClients} {incr i} {
	puts [dict set Clients "LostClient[generateCode 13]" [::LostMC::Connect localhost 7733]]
	#::LostMC::Msg
	after 10
}
}

::LostMC::Connect localhost 7733
vwait zambile
#::LostMC::DrawFirstScreen

#::LostMC::Register adriana test a@driana.net
#::LostMC::Auth adriana test
#::LostMC::Msg lostone "Salut Andrei! Esti?"

#New console
#::LostMC::Auth lostone andrei
#::LostMC::Msg adriana "Scuze ca am intarziat, aveam niste treaba. Ce faci?"
