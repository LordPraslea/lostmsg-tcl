#############
# Lost Msg Chat Server
#############
#LostIMS

package require tls
package require sqlite3
package require md5

package provide LostIMS 0.1

namespace eval LostIMS {
	variable Clients
	variable Channels
	variable Files
	variable Server
	
	sqlite3 MsgDB  [pwd]/db/ServerDb.sqlite
	#1 second timeout in case if db is locked
	MsgDB timeout 1000
	
	set Clients ""
	
	#Server connection
	proc Server {port} {
		variable Server
		set keyfile server.key
		set certfile server.pem
		
		 #If the certificate doesn't exist create it
		if {![file exists $keyfile]} {
			tls::misc req 1024 $keyfile $certfile [list CN "Lost Server" days 7300]
		}
		
		set Server [tls::socket -server ::LostIMS::AcceptConnection -keyfile $keyfile -certfile $certfile $port]
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
    puts $sock "c You are now connected to Lost Server"
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
	
	if {[::LostIMS::VerifyAuth $sock]} {
		set toUser [string tolower [lindex $msg 0]]
		set fromUser [dict get $Clients $sock username]
		
		#To do: Tell sock user doesn't exist.. quietly go further..
		if {[MsgDB exists {SELECT Username FROM Usernames WHERE username=$toUser}]} {
			set msg [lrange $msg 1 end]
			puts "$msg"

			#Check if user is ignored so you don't send messages And maybe tell user he's ignored
			if {![MsgDB exists {SELECT * FROM IgnoreList WHERE Me=$toUser and IgnoredPerson=$fromUser}]} {
				
				#See if user is online to send.. if not.. leave offline msg
				if {![dict exists $Clients $toUser]} {
					set time [unixtime]
					MsgDB eval {INSERT INTO OfflineMessages (ToUser,FromUser,Message,DateSent)	VALUES  ($toUser,$fromUser,$msg,$time)}
				} else  { 	puts [dict get $Clients $toUser sock] "7 $fromUser $msg " }
			}
		} else { puts $sock "3 2" }
	}
}
#Authentificate user to socket
proc ::LostIMS::AuthUser {sock msg} {
	variable Clients

	set errors ""
	#Handle if username exists.. & if password is correct..
	
	set username [string tolower [lindex $msg 0]]
	set password [lindex $msg 1]
	
	array set Client {Username "" Password ""}
	
	MsgDB eval {SELECT Username,password FROM Usernames WHERE username=$username} Client {}

	#Inexistent user when authing
	if {![string match -nocase $Client(Username) $username]} {
		 puts $sock "3 1"
		 lappend errors 3 
	 }
	 #Wrong password
	 if {![string match [::md5::md5 -hex $password] $Client(Password)]} {
		puts $sock "4"
		lappend errors 4 
	 }

	if {[string length $errors] ==  0} {
		#Control if someone is already logged in with this username. If so, log him out and send him a logout message.
		if {[dict exists $Clients $username sock]} {
			set logoutSock [dict get $Clients $username sock] 
			puts $logoutSock 15
			dict unset Clients $logoutSock username
			puts $Clients
		}
		
		dict set Clients $sock username $username
		dict set Clients $username sock $sock
		 
		#Auth is ok
		puts $sock "2"

		#Send Offline Messages to user and either set them all to 1 (read) or delete them all(easier..)
		set messages [MsgDB eval {SELECT DateSent,FromUser,Message FROM OfflineMessages WHERE ToUser=$username}]
		if {$messages != ""} {
			puts $sock "14 $messages"
			MsgDB eval {DELETE FROM OfflineMessages WHERE ToUser=$username}
		}
	}
}

#Register the user
proc ::LostIMS::RegUser {sock msg} {
	variable Clients
	set errors ""
	
	#2 	register <username> <password> <e-mail> <nickname> <full name> <birthdate> <Gender> <Location>
	if {[llength $msg] < 3} {
		puts $sock "0 register <username> <password> <e-mail>"
		lappend errors 0 
	}
	foreach {username password email} $msg {} 

	#Username already exists
	if {[MsgDB exists {SELECT Username,Password FROM Usernames WHERE username=$username}]} {
		puts $sock 5
		lappend errors 5
	}

	if {[string length $errors] ==  0} {
		set creationDate [unixtime]
		set lastIp [dict get $Clients $sock host]
		set password [::md5::md5 -hex $password]
		MsgDB eval {INSERT INTO Usernames (Username,Password,Email,CreationDate,LastIp)
			VALUES  ($username,$password,$email,$creationDate,$lastIp)}
			
		#Everything went fine.. Registered :)
		puts $sock "6 $username"
	}
}

proc ::LostIMS::FileManagement {sock type msg} {
	variable Clients
	if {[::LostIMS::VerifyAuth $sock]} {
		set yourUser [dict get $Clients $sock username]
		set otherUser [lindex  $msg 0]
		
		#Only verify if user is actually online.. otherwise just ignore the request
		if {[dict exists $Clients $otherUser sock]} {
			set otherUserSock [dict get $Clients $otherUser sock]
			
			# 1 Request for file (generate unique code for file)
			# 2 Wants to get file
			# 3 Rejected file transfer
			switch -- $type {
				1 { puts $otherUserSock "8 $yourUser [lrange $msg 1 end] [generateCode 13]" }
				2 { puts $otherUserSock "9 $yourUser [lindex $msg 1]" }
				3 { puts $otherUserSock "10 $yourUser [lindex $msg 1]" }
			}
		}
	}
}
proc ::LostIMS::listConnections {time} {
	variable Clients
	puts "You have [llength [dict keys $Clients]] connections active"
	after $time ::LostIMS::listConnections $time
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

proc send_mail {recipient subject body {Bcc ""}} {
    package require smtp
    package require mime
    package require base64
    set token [mime::initialize -canonical text/html  -string $body]
    mime::setheader $token Subject $subject
	mime::setheader $token From "\"Life Beyond Apocalypse\" <no-reply@lifebeyondapocalypse.net>" -mode append
    mime::setheader $token To $recipient -mode append
    if {$Bcc != ""} {  mime::setheader $token Bcc $Bcc -mode append }
	smtp::sendmessage $token -ports 587 -recipients $recipient -servers smtp.gmail.com -username lifebeyondapocalypse@gmail.com -password [::base64::decode "RHVtbmV6ZXVsMw=="]
    smtp::sendmessage $token -ports 25 -recipients $recipient -servers localhost
    mime::finalize $token
}
if {0} {
 -header[list From "Life Beyond Apocalypse" no-reply@lifebeyondapocalypse.net]] \
		-header[list To recipient@host.com]] \
}

#Create Database Function
proc CreateDb {} {
	#Usernames  <e-mail> <full name> <birthdate> <Gender> <Location>
	MsgDB eval {CREATE TABLE IF NOT EXISTS Usernames(id INTEGER PRIMARY KEY autoincrement, Username TEXT COLLATE NOCASE, Password TEXT, Nickname TEXT, 
	Email TEXT, FullName TEXT,Birthdate INT, Gender TEXT,Location TEXT,
	Level INT DEFAULT 0, LastLogin INT DEFAULT 0, CreationDate INT DEFAULT 0, LastIP TEXT)}
	#Friends
	MsgDB eval {CREATE TABLE IF NOT EXISTS Friends(Me TEXT COLLATE NOCASE, MyFriend TEXT COLLATE NOCASE, DateAdded INT DEFAULT 0,
		Accepted INT DEFAULT 0, InGroup TEXT COLLATE NOCASE, PRIMARY KEY (Me,MyFriend))}
	#Channels
	MsgDB eval {CREATE TABLE IF NOT EXISTS Channels(name TEXT PRIMARY KEY COLLATE NOCASE, owner TEXT COLLATE NOCASE, description TEXT)}
	#Friends Groups
	MsgDB eval {CREATE TABLE IF NOT EXISTS FriendGroups(Name TEXT PRIMARY KEY COLLATE NOCASE, owner TEXT COLLATE NOCASE)}
	#Ignore List
	MsgDB eval {CREATE TABLE IF NOT EXISTS IgnoreList(Me TEXT COLLATE NOCASE, IgnoredPerson TEXT COLLATE NOCASE, DateAdded INT DEFAULT 0,
		Reason TEXT, PRIMARY KEY (Me,IgnoredPerson))}
	#Offline messages
	MsgDB eval {CREATE TABLE IF NOT EXISTS OfflineMessages(id INTEGER PRIMARY KEY AUTOINCREMENT, ToUser TEXT COLLATE NOCASE, FromUser TEXT COLLATE NOCASE, DateSent INT DEFAULT 0,
		Message TEXT, read INT DEFAULT 0)}
}
if {0} {
	#And the winner is... Array's have less overhead but are slower
	for {set i 0} {$i<30000} {incr i} {
		dict set gigi lost$i username lostUserNameSoWhatBigDeal$i
		dict set gigi lost$i password lostpass$i
	}
	#Dict VS Array in memory usage
	for {set i 0} {$i<30000} {incr i} {
		set gigi(lost$i,username) lostUserNameSoWhatBigDeal$i
		set gigi(lost$i,password) lostpass$i
	}
}
after 1000  ::LostIMS::listConnections 13000
CreateDb
LostIMS::Server 7733



