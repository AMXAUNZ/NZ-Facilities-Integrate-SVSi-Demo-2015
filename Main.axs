PROGRAM_NAME='Main'

DEFINE_DEVICE

dvDebug		=	0:0:0
dvMaster	=	0:1:0
dvTP		=	10001:1:0

// SVSi Devices
dvSvsiControl	=	0:2:0	// SVSi n8001 Controller
dvSvsiKVM		= 	0:3:0   // SVSi Decoder

DEFINE_CONSTANT

// Drag & Drop Constants
integer nDragStarted	=	1410	// When a drag is initiated after holding for 1sec	
integer nDragEnter 		= 	1411	// When a draggable enters a droppable target area
integer nDragExit		=	1412	// When a draggable leaves a droppable target area
integer nDrop			=	1413	// When a draggable is dropped on a target
integer nDragCancelled	= 	1414	// When a drag is cancelled

// Touchpanel Buttons
integer btnDragNuc1		=	1
integer btnDragNuc2		=	2
integer btnDragPS3		=	3
integer btnDragATV		=	4
integer btnDropLCD1		=	5
integer btnDropLCD2		=	6
integer	btnDropLCD3		=	7
integer btnDropLCD4		=	8
integer btnDropLCD4K	=	9
integer btnDropWall 	= 	10
integer btnStart		=	100
integer	btnShutDown		=	200

//drop area feedback
integer btnVideoWallDropArea	=	30	//feedback area for the video wall drop targets
integer btn4KDropArea			=	31	//feedback area for the 4K KVM drop target

// SVSi Constant
integer TCP_Port			=	50020	// SVSi Comms Port
integer KVM_TCP_Port		= 	50002 	// KVM Comms Port
integer Telnet_Port			=	23		// Telnet Port
integer SVSi_SESSION_STS	= 	15		// SVSi Connection Status Button

// Protocol identifiers
integer TCP				= 	1
integer UDP				= 	2
integer UDPwRx			= 	3

DEFINE_VARIABLE

// IP Address Variables
volatile char sMasterIP[]	= '192.168.15.21'   // NX master
volatile char sSwitcherIP[]	= '192.168.15.29'	// SVSi N8001 Controller
volatile char sKVMDecoderIP[] = '192.168.15.28'  // SVSi KVM decoder

// Drag & Drop Tracking Variables
integer nDraggableButtons[] 	= 	{btnDragNuc1, btnDragNuc2, btnDragPS3, btnDragATV}
integer nDropTargets[]			=	{btnDropLCD1, btnDropLCD2, btnDropLCD3, btnDropLCD4, btnDropLCD4K, btnDropWall}
integer nDragAddress			=	0		//Used in custom drag events
integer nValidTarget
integer nMP1Source
integer nMP2Source
integer nMP3Source
integer nMP4Source
integer nMP5Source 
integer nWallMode				= 	0

// nTracking -- tracks the touch panel source actions
persistent integer nTracking[10]     	= {1,1,1,1,1,1,1,1,1,1}

// nStreamStatus -- tracks the feedback from the encoders
persistent integer nStreamStatus[10]    = {1,1,1,1,1,1,1,1,1,1}

// Combined Array
volatile char sCombined[][15]   =
{
	{'192.168.15.30'},		// Encoder for NUC1
	{'192.168.15.31'},		// Encoder for NUC2
	{'192.168.15.32'},		// Encoder for PS3
	{'192.168.15.33'},		// Encoder for Apple TV
	{'192.168.15.24'},		// Decoder for Top Left
	{'192.168.15.25'}, 		// Decoder for Top Right
	{'192.168.15.26'},		// Decoder for Bottom Left
	{'192.168.15.27'},		// Decoder for Bottom Right
	{'192.168.15.28'}		// Decoder for Sony 4k
}

// SVSi Encoders
#WARN 'Change encoder IP Addresses when system is configured!!'

volatile char sEncoders[][15]	=   
{
	{'192.168.15.30'},		// Encoder for NUC1
	{'192.168.15.31'},		// Encoder for NUC2
	{'192.168.15.32'},		// Encoder for PS3
	{'192.168.15.33'}		// Encoder for Apple TV
}

// SVSi Decoders
#warn 'Change decoder IP Addresses when system is configured!!'

volatile char sDecoders[][15]	=   
{
	{'192.168.15.24'},		// Decoder for Top Left
	{'192.168.15.25'}, 	 	// Decoder for Top Right
	{'192.168.15.26'},		// Decoder for Bottom Left
	{'192.168.15.27'},		// Decoder for Bottom Right
	{'192.168.15.28'}		// Decoder for Sony 4k
}


DEFINE_MUTUALLY_EXCLUSIVE
([dvTP,btnDragNuc1],[dvTP,btnDragNuc2],[dvTP,btnDragPS3],[dvTP,btnDragATV])

define_function fnStartMonitoringDecoders()
{
    stack_var x 
    
    for(x=1; x<=length_array(sDecoders); x++)
    {
	send_string dvSvsiControl,"'monitor ',sDecoders[x],13"
	send_string dvMaster,"'Monitoring decoder#: ',itoa(x),10,13"
    }
}

define_function fnStartClientSessionWithNCommand()
{
    // If the connection broke down before the session was closed,
    // a new client request would be denied.
    // Therefore, closing a session first ensures that a new session will always open.
    ip_client_close(dvSvsiControl.port)
    
    // Give a short grace period for any open session to close before opening a new
    // session.
    wait 2
    {
		ip_client_open(dvSvsiControl.port, sSwitcherIP, TCP_PORT, TCP)
		
		wait 2
		{
			fnStartMonitoringDecoders()
		}
    }
}

define_function fnEndClientSessionWithNCommand()
{
    ip_client_close(dvSvsiControl.port)
}

define_function fnStartClientSessionKVMDecoder()
{
    // If the connection broke down before the session was closed,
    // a new client request would be denied.
    // Therefore, closing a session first ensures that a new session will always open.
    ip_client_close(dvSvsiKVM.port)
    
    // Give a short grace period for any open session to close before opening a new
    // session.
    wait 2
    {
		ip_client_open(dvSvsiKVM.port, sKVMDecoderIP, KVM_TCP_PORT, TCP)
		
    }
}

// Switches the supplied decoder IP to the supplied encoder IP
define_function fnSwitch(char decoder, char encoder)
{
  send_string dvSvsiControl, "'switch ', decoder, ' ', encoder, 13"
}

// Swithes decoder KVM to the supplied encoder KVM
define_function fnSwitchKVM(char encoder)
{
  send_string dvSvsiKVM, "'KVMMasterIP:', encoder, 13"
}

// Used to disable crop on all decoders, typically leaving wall mode
define_function fnCropOff()
{
	stack_var x 
    for(x=1; x<=length_array(sDecoders); x++)
    {
	send_string dvSvsiControl,"'cropref ', sDecoders[x], ' 0 0 0 0', 13"
    } 
}

// Iterates through Decoders and sets stream to what is stored in nTracking
define_function fnRestoreSource()
{
	stack_var x
	stack_var y
	for(x=1; x<=length_array(sDecoders); x++)
    {
	y = nTracking[x+4] // need to add 4 to address array correctly
	//send_string dvDebug, "sDecoders[x], sEncoders[y], x, y"
	fnSwitch(sDecoders[x], sEncoders[y])
    }
}


define_function fnResetButtons()
// Iterates through buttons and sets their states
{
	stack_var x 
    for(x=1; x<=length_array(nDropTargets); x++)
    {
	SEND_COMMAND dvTP,"'^ANI-',ITOA(nDropTargets[x]),',1,1,0'"
    } 
}

define_function fnVideoWall(source)
// Sends the videowall command to the N8001 to select the preset wall
{
	// this requires the N8001 to have test wall have screens for each source
	// they will need to be named source1, source2 .... 
	nWallMode = 1
	send_string dvDebug, "'videowall "test wall" "source', itoa(source),'"', 13"
	send_string dvSvsiControl, "'videowall "test wall" "source', itoa(source),'"', 13"
}

define_function fnConvertIPtoButton(ip)
//Takes an IP and finds its index in the array
{
	stack_var x
    for(x=1; x<=length_array(sCombined); x++)
    {
	if (sCombined[x] == ip)
		{
		return 
		}
    } 
}

DEFINE_START

fnStartClientSessionWithNCommand()
fnStartClientSessionKVMDecoder()

DEFINE_EVENT

data_event[dvSvsiControl]
{
	string:
	{
		// need to parse this and do feed back
		// this comes in the form:
		// Status Packet Sample: <status>169.254.237.181;1;0;0;0;live;0;6995;0;1;0;0;720p60</status>
		// Status Packet Order: <status>IP address; communication;dvioff;scaler;display state;mode;audio state;video stream;audiostream;playlist;colorspace;hdmiaudio;resolution</status>
		// we would need to drop <status> and then split on ';'
		
		// this is an example encoder status:
		// Status Packet Resp <status>169.254.114.220;1;0;0;0;live;1;300;0;1;0;0;720p60</status>
		// Status Packet Field <status>IP address; Communication; dvioff;scaler;source state; mode; audio state; stream#; stream#; playlist; colorspace;hdmiaudio;resolution;</status>
		// maybe we could query the encoder for its stream number and store 
		// this in an array, to reference when we get a status update from a 
		// decoder (you get one of these whenever you do a switch)

		STACK_VAR char text[200], output[50], sending_unit[15], stream[15]
		STACK_VAR INTEGER count, x, result
		
		text = data.text
		send_string dvDebug, text
		REMOVE_STRING(text, '<status>', 1)
		
		count = 0
		sending_unit = ""
		stream = ""
		// loop through finding each ; until there are no more (dont worry about 
		// the last one)
		while (FIND_STRING(text, ';', 1) != 0) 
		{	
			count++
			output = LEFT_STRING(text, (FIND_STRING(text, ';', 1)))
			REMOVE_STRING(text, output, 1)
			if (count == 1) // IP Address of sending unit
			{
				sending_unit = LEFT_STRING(output, (LENGTH_STRING(output) - 1))
			}
			if (count == 8) // Stream number
			{
				stream = LEFT_STRING(output, (LENGTH_STRING(output) - 1))
			}
			// send_string dvDebug, "'Count= ', itoa(count), ' output= ', output"
		}
		for (count = 1; count<=(LENGTH_ARRAY(sCombined)); count++)
		{
			if (sCombined[count] == sending_unit) // Find the address in the array
			{
				// Feed back here count is drop button address and 
				// stream is source button address 
				nStreamStatus[count] = atoi(stream)
			}
		}
		// send_string dvDebug, "'Done processing'"
		send_string dvDebug, "'Status update from ', sending_unit, ' is using stream ', stream"
		for(x=1; x<=length_array(sCombined); x++)
			{
			if (sCombined[x] == sending_unit)
				{
				SEND_COMMAND dvTP,"'^ANI-',ITOA(x),',1,1,0'"
				}
			}
		}
}

data_event[dvTP]
{
  online:
  {
	//ensure touchpanel is in starting state when it comes online
	// Iterate through nStreamStatus or nTracking to set starting state
	off [dvTP, nDraggableButtons]
	fnResetButtons()
	SEND_COMMAND dvTP,"'^ANI-',ITOA(btnVideoWallDropArea),',1,1,0'"
	SEND_COMMAND dvTP,"'^ANI-',ITOA(btn4KDropArea),',1,1,0'"
  }
}

//custom event for a START(1410)
custom_event[dvTP, nDraggableButtons, nDragStarted]
{
  nDragAddress = custom.ID	//find the source button that initiated the custom event and store it
  //show the drop areas
  SEND_COMMAND dvTP,"'^ANI-',ITOA(btnVideoWallDropArea),',2,2,0'"
  SEND_COMMAND dvTP,"'^ANI-',ITOA(btn4KDropArea),',2,2,0'"
  
  //turn on the source button the user has selected while a drag is in progress
  ON[dvTP,nDragAddress]
}

//custom event for ENTER(1411)
custom_event[dvTP, nDropTargets, nDragEnter]
{
  //when a drag button enters a valid drop area change to state 3.
  //change based on the drop area that triggered the event
  SEND_COMMAND dvTp,"'^ANI-',ITOA(custom.id),',3,3,0'"
}

//cusotm event for a EXIT(1412)
custom_event[dvTP, nDropTargets, nDragExit]
{
  SEND_COMMAND dvTP,"'^ANI-',ITOA(custom.id),',1,1,0'"
}

//custom event for DROP (1413)
custom_event[dvTP, nDropTargets, nDrop]
{	
  //put the drop target button into the 'switching' state 
  SEND_COMMAND dvTP,"'^ANI-',ITOA(custom.id),',2,2,0'"
  
  //turn off the draggable button when the drop has occured
  OFF [dvTP,nDragAddress]
  
  //send both drop target areas back to state 1
  SEND_COMMAND dvTP,"'^ANI-',ITOA(btnVideoWallDropArea),',1,1,0'"
  SEND_COMMAND dvTP,"'^ANI-',ITOA(btn4KDropArea),',1,1,0'"
  
  //switch the video source to its destination
  // there are two modes 1. normal 2. video wall
  // first check if it has been dropped on video wall
  if (custom.value2 == btnDropWall)
	{
		//to go to videowall just call video wall and turn off feed back
		fnVideoWall(custom.value1)
		SEND_COMMAND dvTP,"'^ANI-',ITOA(custom.id),',1,1,0'"
	}
  // dropped on another target, check if it was the 4k display
  else if (custom.value2 == btnDropLCD4K)
	{
		//Do the switch for the 4k display
		//Check if no switch is necessary
		if (nTracking[custom.value2] == custom.value1)
			{
				// No switch, just update button
				SEND_COMMAND dvTP,"'^ANI-',ITOA(custom.value2),',1,1,0'"
			}
		nTracking[custom.value2] = custom.value1
		//fnSwitch(sCombined[custom.value2], sCombined[custom.value1])
		fnSwitchKVM(sCombined[custom.value1])
	}
  // dropped on another target, check if we are in video wall first
  else if (nWallMode == 1)
	{
		// In video wall mode, need to get out
		// store switch in tracking 
		// clear wall and restore video 
		// clear button feed back
		fnCropOff()
		nWallMode = 0
		nTracking[custom.value2] = custom.value1
		fnRestoreSource()
		SEND_COMMAND dvTP,"'^ANI-',ITOA(custom.value2),',1,1,0'"
	}
  else if (nWallMode == 0)
	{
		// Not in video wall 
		// Check for no switch
		if (nTracking[custom.value2] == custom.value1)
			{
				// No switch, just update button
				SEND_COMMAND dvTP,"'^ANI-',ITOA(custom.value2),',1,1,0'"
			}
		nTracking[custom.value2] = custom.value1
		fnSwitch(sCombined[custom.value2], sCombined[custom.value1])
	}
}

//cusotm event for a CANCEL(1414)
custom_event[dvTP,nDraggableButtons,nDragCancelled]
{
  //set everything back to state 1 as nothing is going to happen anymore :(
  SEND_COMMAND dvTp,"'^ANI-',ITOA(btnVideoWallDropArea),',1,1,0'"
  SEND_COMMAND dvTp,"'^ANI-',ITOA(btn4KDropArea),',1,1,0'"
  
  //turn off the draggable button
  off [dvTP, nDragAddress]
}

