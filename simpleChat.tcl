#############
# Simple Chat
#############
#LostIMS

package provide LostIMS 0.1

namespace eval LostIMS {
	variable Clients
	variable Channels
	variable Files
	variable Server
	

	#Server connection
	proc Server {port} {
		variable Server
		#Jump to the command that handles connections
		set Server [socket -server ::LostIMS::AcceptConnection  $port]
		puts "Lost Instant Messenger Server started"
		vwait forever
	}
	namespace export *
}


# AcceptConnection --
#	Accept a connection from a new client.	This is called after a new socket connection 	has been created by Tcl.

proc ::LostIMS::AcceptConnection {sock addr port} {
    variable Clients

    # Record the client's information
    puts "Accept $sock from $addr port $port"
    dict set Clients $sock host $addr
    dict set Clients $sock port $port
    
    # Ensure that each "puts" by the server results in a network transmission
   
    fconfigure $sock -buffering line -blocking 0
	
    # Set up a callback for when the client sends data
    fileevent $sock readable [list ::LostIMS::HandleClient $sock]
	
    #Let the client know he's connected
    puts $sock "You are now connected to Lost Server"
}

# HandleClient --
#	This procedure is called when the server can read data from the client

proc ::LostIMS::HandleClient {sock} {
    variable Clients

    # Check end of file or abnormal connection drop,
    # then echo data back to the client.

    if {[eof $sock] || [catch {gets $sock line}]} {
		#VERY IMPORTANT, Logout must be THE LAST one
		puts "Close $sock [dict get $Clients $sock host]"
		close $sock
		#VERY IMPORTANT, Logout must be THE LAST one
		Logout $sock
	} else {
		::LostIMS::CommandSwitch  $sock $line
    }
}

proc ::LostIMS::CommandSwitch {sock msg} {
	#debugging purpose
	#puts "$sock said: $msg"
	switch -- [lindex $msg 0] {
		c { puts "Ok" }
		1 { ::LostIMS::AuthUser $sock [lrange $msg 1 end] }
		2 { ::LostIMS::RegUser $sock [lrange $msg 1 end] }
		3 { ::LostIMS::SendMessage $sock [lrange $msg 1 end] }
		4 {
			#Buzz action to user
		}
		5 { ::LostIMS::FileManagement $sock 1 [lrange $msg 1 end] }
		6 { ::LostIMS::FileManagement $sock 2 [lrange $msg 1 end] }
		7 { ::LostIMS::FileManagement $sock 3 [lrange $msg 1 end] }
		default { puts $sock "0 Invalid command.. please try again" }
	}
}
proc ::LostIMS::Logout {sock} {
	variable Clients
	#Unset the username
	if {[dict exists $Clients $sock username]} {
		set username [dict get $Clients $sock username]
		if {[dict exists $Clients $username sock]} {
			dict unset Clients $username
		}
	}
	dict unset Clients $sock
}
#Verify if authentificated
proc ::LostIMS::VerifyAuth {sock} {
	variable Clients
	if {[dict exists $Clients $sock username]} {
		return 1
	} else  {
		puts $sock "1"
		return 0
	}
}
#Send Message from one to another
proc ::LostIMS::SendMessage {sock msg} {
	variable Clients
	puts [dict get $Clients $toUser sock] "7 $fromUser $msg " 
}


#############
# General commands
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

LostIMS::Server 7733


#############
# Lost Msg Client
#############

package provide LostMC 0.1

namespace eval LostMC {
	variable server
	variable files

	proc Connect {host port} {
		variable server
		set server [socket $host $port]
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
proc ::LostMC::Register {username password email nickname fullname birthdate gender location} {
	variable server
	puts $server "2 $username $password $email $nickname $fullname $birthdate $gender $location"
}
proc ::LostMC::Auth {username password} {
	variable server
	puts $server "1 $username $password"
}
proc ::LostMC::Msg {username msg} {
	variable server
	puts $server "3 $username [list $msg]"
}


::LostMC::Connect localhost 7733
