import SwiftUI
import ParsecSDK

struct ParsecView:View
{
	var controller:ContentView?
	
	@State var showDCAlert:Bool = false
	@State var DCAlertText:String = "Disconnected (reason unknown)"
    @State var metricInfo:String = "Loading..."
	
	@State var hideOverlay:Bool = false
	@State var showMenu:Bool = false

	@State var muted:Bool = false
    @State var preferH265:Bool = true
	
	//@State var showDisplays:Bool = false
	
	init(_ controller:ContentView?)
	{
		self.controller = controller
	}

	var body:some View
	{
		ZStack()
		{
			// Stream view controller
			//switch SettingsHandler.renderer
			//{
				//case .opengl:
				ParsecGLKViewController(onBeforeRender:poll)
						.zIndex(0)
						.edgesIgnoringSafeArea(.all)
				//case .metal:
				//	Text("Metal is a work in progress, check back soon!")
				//		.background(Color.black)
				//		.foregroundColor(.white)
					/*ParsecMetalViewController(onBeforeRender:poll)
						.zIndex(0)
						.edgesIgnoringSafeArea(.all)*/
			//}
			
			// Input handlers
			TouchHandlingView(handleTouch:onTouch, handleTap:onTap)
				.zIndex(2)
			UIViewControllerWrapper(KeyboardViewController())
				.zIndex(-1)
            UIViewControllerWrapper(GamepadViewController())
			    .zIndex(-2)
			
			// Overlay elements
			if showMenu
            {
                VStack()
                {
                    Text("\(metricInfo)")
                        .frame(minWidth:200, maxWidth:.infinity, maxHeight:20)
                        .multilineTextAlignment(.leading)
                        .font(.system(size: 10))
                        .lineSpacing(20)
                        .lineLimit(nil)
                }
                .background(Rectangle().fill(Color("BackgroundPrompt").opacity(0.75)))
                .foregroundColor(Color("Foreground"))
                .frame(maxHeight: .infinity, alignment: .top)
                .zIndex(1)
				.edgesIgnoringSafeArea(.all)
            }
			
			VStack()
			{
				if !hideOverlay
				{
					HStack()
					{
						Button(action:{ showMenu.toggle() })
						{
							Image("IconTransparent")
								.resizable()
								.aspectRatio(contentMode: .fit)
								.frame(width:48, height:48)
								.background(Rectangle().fill(Color("BackgroundPrompt").opacity(showMenu ? 0.75 : 1)))
								.cornerRadius(8)
								.opacity(showMenu ? 1 : 0.25)
						}
						.padding()
						.edgesIgnoringSafeArea(.all)
						Spacer()
					}
				}
				if showMenu
				{	
					HStack()
					{
						VStack(spacing:3)
						{
							Button(action:disableOverlay)
							{
								Text("Hide Overlay")
									.padding(12)
									.frame(maxWidth:.infinity)
									.multilineTextAlignment(.center)
							}
							Button(action:toggleMute)
							{
								Text("Sound: \(muted ? "OFF" : "ON")")
									.padding(12)
									.frame(maxWidth:.infinity)
									.multilineTextAlignment(.center)
							}
							/*Button(action:{showDisplays = true})
							{
								Text("Switch Display")
									.padding(12)
									.frame(maxWidth:.infinity)
									.multilineTextAlignment(.center)
							}
							.actionSheet(isPresented:$showDisplays, content:genDisplaySheet)*/
							/*Button(action:{inSettings = true})
							{
								Text("Settings")
									.padding(12)
									.frame(maxWidth:.infinity)
									.multilineTextAlignment(.center)
							}*/
							Rectangle()
								.fill(Color("Foreground"))
								.opacity(0.25)
								.frame(height:1)
							Button(action:disconnect)
							{
								Text("Disconnect")
									.foregroundColor(.red)
									.padding(12)
									.frame(maxWidth:.infinity)
									.multilineTextAlignment(.center)
							}
						}
						.background(Rectangle().fill(Color("BackgroundPrompt").opacity(0.75)))
						.foregroundColor(Color("Foreground"))
						.frame(maxWidth:175)
						.cornerRadius(8)
						.padding(.horizontal)
						//.edgesIgnoringSafeArea(.all)
						Spacer()
					}
				}
				Spacer()
			}
			.zIndex(2)
		}
		.statusBar(hidden:true)
		.alert(isPresented:$showDCAlert)
		{
			Alert(title:Text(DCAlertText), dismissButton:.default(Text("Close"), action:disconnect))
		}
		.onAppear(perform:post)
		.edgesIgnoringSafeArea(.all)
	}
	
	func post()
	{
		CParsec.applyConfig()
		CParsec.setMuted(muted)
		
		hideOverlay = SettingsHandler.noOverlay
	}
	
	func poll()
	{
		if showDCAlert
		{
			return // no need to poll if we aren't connected anymore
		}
		
		var pcs = ParsecClientStatus()
		let status = CParsec.getStatusEx(&pcs)
		
		if status != PARSEC_OK
		{
			DCAlertText = "Disconnected (code \(status.rawValue))"
			showDCAlert = true
			return
		}
		
		CParsec.pollAudio()
		
		if showMenu
		{
			let str = String.fromBuffer(&pcs.decoder.0.name.0, length:16)
			metricInfo = "Decode \(String(format:"%.2f", pcs.`self`.metrics.0.decodeLatency))ms    Encode \(String(format:"%.2f", pcs.`self`.metrics.0.encodeLatency))ms    Network \(String(format:"%.2f", pcs.`self`.metrics.0.networkLatency))ms    Bitrate \(String(format:"%.2f", pcs.`self`.metrics.0.bitrate))Mbps    \(pcs.decoder.0.h265 ? "H265" : "H264") \(pcs.decoder.0.width)x\(pcs.decoder.0.height) \(pcs.decoder.0.color444 ? "4:4:4" : "4:2:0") \(str)"
		}
	}
	
	func disableOverlay()
	{
		hideOverlay = true
		showMenu = false
	}
	
	func toggleMute()
	{
		muted.toggle()
		CParsec.setMuted(muted)
	}
	
	/*func genDisplaySheet() -> ActionSheet
	{
		let len:Int = 16
		var outputs = [ParsecOutput?](repeating:nil, count:len)
		ParsecGetOutputs(&outputs, UInt32(len))
		print("Listing \(outputs.count) displays")

		func getDeviceName(_ output:ParsecOutput) -> String
		{
			return withUnsafePointer(to:output.device)
			{
				$0.withMemoryRebound(to:UInt8.self, capacity:MemoryLayout.size(ofValue:$0))
				{
					String(cString:$0)
				}
			}
		}

		let buttons = outputs.enumerated().map
		{ i, output in
			Alert.Button.default(Text("\(i) - \(getDeviceName(output))"), action:{print("Selected device \(i)")})
		}
		return ActionSheet(title:Text("Select a Display:"), buttons:buttons + [Alert.Button.cancel()])
	}*/
	
	func disconnect()
	{
		CParsec.disconnect()

		if let c = controller
		{
			c.setView(.main)
		}
	}

	func onTouch(typeOfTap:ParsecMouseButton, location:CGPoint, state:UIGestureRecognizer.State)
	{
		// Log the touch location
		print("Touch location: \(location)")
		print("Touch type: \(typeOfTap)")
		print("Touch state: \(state)")

		// print("Touch finger count:" \(pointerId))
		// Convert the touch location to the host's coordinate system
		let screenWidth = UIScreen.main.bounds.width
		let screenHeight = UIScreen.main.bounds.height
		let x = Int32(location.x * CGFloat(CParsec.hostWidth) / screenWidth)
		let y = Int32(location.y * CGFloat(CParsec.hostHeight) / screenHeight)

		// Log the screen and host dimensions and calculated coordinates
		print("Screen dimensions: \(screenWidth) x \(screenHeight)")
		print("Host dimensions: \(CParsec.hostWidth) x \(CParsec.hostHeight)")
		print("Calculated coordinates: (\(x), \(y))")

		// Send the mouse input to the host
		switch state
		{
			case .began:
				CParsec.sendMouseMessage(typeOfTap, x, y, true)
			case .changed:
				CParsec.sendMousePosition(x, y)
			case .ended, .cancelled:
				CParsec.sendMouseMessage(typeOfTap, x, y, false)
			default:
				break
		}
	}

	func onTap(typeOfTap:ParsecMouseButton, location:CGPoint)
	{
		// Log the touch location
		print("Touch location: \(location)")
		print("Touch type: \(typeOfTap)")

		// print("Touch finger count:" \(pointerId))
		// Convert the touch location to the host's coordinate system
		let screenWidth = UIScreen.main.bounds.width
		let screenHeight = UIScreen.main.bounds.height
		let x = Int32(location.x * CGFloat(CParsec.hostWidth) / screenWidth)
		let y = Int32(location.y * CGFloat(CParsec.hostHeight) / screenHeight)

		// Log the screen and host dimensions and calculated coordinates
		print("Screen dimensions: \(screenWidth) x \(screenHeight)")
		print("Host dimensions: \(CParsec.hostWidth) x \(CParsec.hostHeight)")
		print("Calculated coordinates: (\(x), \(y))")

		// Send the mouse input to the host
		CParsec.sendMouseMessage(typeOfTap, x, y, true)
		CParsec.sendMouseMessage(typeOfTap, x, y, false)
	}

	func handleKeyCommand(sender:UIKeyCommand)
	{
		CParsec.sendKeyboardMessage(sender:sender)
	}
}
