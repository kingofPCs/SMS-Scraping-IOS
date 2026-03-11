# SMS-Scraping-IOS
Quick little tool to scrape SMS / Text Messages from an iOS device for evaluation


How it works:
iOS doesn’t have a public API to read SMS/iMessage directly, so the app works by importing the chat.db SQLite database file — the actual database Apple uses to store all your messages.
App flow:
	1.	Open the app → tap Import chat.db → pick the file from Files
	2.	It parses all conversations using SQLite3 and shows a preview with stats (message count, conversation count)
	3.	Export as Text File or Export as CSV → share via AirDrop, save to Files, etc.
Getting chat.db (3 options in the app’s instructions):
	∙	From a Mac with iMessage synced: ~/Library/Messages/chat.db
	∙	From an iPhone backup: Make an unencrypted local backup, find the file 3d0d7e5fb2ce288813306e4d4636395e047a3d28 in the backup folder
	∙	From iMazing/3uTools: Browse device filesystem and export it
To deploy on TestFlight:
	1.	Open SMSScraper/SMSScraper.xcodeproj in Xcode
	2.	Change the bundle ID (com.smsscraper.app) to match your Apple Developer account
	3.	Select your Team under Signing & Capabilities
	4.	Add an app icon (1024x1024) to the AppIcon asset
	5.	Archive → Upload to App Store Connect → TestFlight