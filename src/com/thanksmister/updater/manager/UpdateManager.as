/*
UpdateManager
This class uses the ApplicationUpdater framework for creating an update dialog similar
to the ApplicationUpdaterUI framework used to update Adobe AIR applications.

How to use:

Main.mxml

import com.thanksmister.UpdateManager;
var updater:UpdateManager = new UpdateManager(false, false);
updater.checkNow() to open manually.

updater.xml in config folder

<?xml version="1.0" encoding="utf-8"?>
<configuration xmlns="http://ns.adobe.com/air/framework/update/configuration/1.0" >
<url>http://localHost/desktop/thanksmister/update.xml</url>
<delay>.003</delay>
</configuration>

Change the delay node to the update interval time. Setting the delay to 0 will prevent automatic update checks.
The default inteval is 3 mintues. Alternative you can call updater.checkNow() to check manually. The url node
should point to the update.xml file (located in server folder in these files) to the server along with the AIR
file for the update.


This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.

Author: Michael Ritchie
www.thanksmister.com
michael.ritchie@gmail.com
*/
package com.thanksmister.updater.manager
{
	import air.update.ApplicationUpdater;
	import air.update.events.DownloadErrorEvent;
	import air.update.events.StatusFileUpdateErrorEvent;
	import air.update.events.StatusFileUpdateEvent;
	import air.update.events.StatusUpdateErrorEvent;
	import air.update.events.StatusUpdateEvent;
	import air.update.events.UpdateEvent;
	
	import com.thanksmister.updater.components.UpdateDialog;
	
	import flash.desktop.NativeApplication;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	public class UpdateManager
	{
		private var appUpdater:ApplicationUpdater;
		private var appVersion:String;
		private var baseURL:String;
		private var updaterDialog:UpdateDialog;
		private var configurationFile:File;
		private var isFirstRun:String;
		private var upateVersion:String;
		private var applicationName:String;
		private var installedVersion:String;
		private var description:String;
		
		private var initializeCheckNow:Boolean = false;
		private var isInstallPostponed:Boolean = false;
		private var showCheckState:Boolean = true;
		private var showNoUpdateState:Boolean = false;
		
		/**
		 * Constructer for UpdateManager Class
		 *
		 * @param showCheckState Boolean value to show the Check Now dialog box
		 * @param initializeCheckNow Boolean value to initialize application and run check on instantiation of the Class
		 * @param showNoUpdateState Boolean value to show dialog if there is no update available, set true on manual update
		 * */
		public function UpdateManager(showCheckState:Boolean = false, initializeCheckNow:Boolean = false, showNoUpdateState:Boolean = false)
		{
			this.showCheckState = showCheckState;
			this.configurationFile = new File("app:/assets/data/update.xml");
			this.initializeCheckNow = initializeCheckNow;
			this.showNoUpdateState = showNoUpdateState;
			initialize();
		}
		
		public function checkNow():void
		{
			isInstallPostponed = false;
			if(showCheckState) {
				createDialog(UpdateDialog.CHECK_UPDATE);
			} else {
				appUpdater.checkNow();
			}
		}
		
		//---------- ApplicationUpdater ----------------//
		
		private function initialize():void
		{
			if(!appUpdater){
				appUpdater = new ApplicationUpdater();
				appUpdater.configurationFile = configurationFile;
				appUpdater.addEventListener(UpdateEvent.INITIALIZED, updaterInitialized);
				appUpdater.addEventListener(StatusUpdateEvent.UPDATE_STATUS, statusUpdate);
				appUpdater.addEventListener(UpdateEvent.BEFORE_INSTALL, beforeInstall);
				appUpdater.addEventListener(StatusUpdateErrorEvent.UPDATE_ERROR, statusUpdateError);
				appUpdater.addEventListener(UpdateEvent.DOWNLOAD_START, downloadStarted);
				appUpdater.addEventListener(ProgressEvent.PROGRESS, downloadProgress);
				appUpdater.addEventListener(UpdateEvent.DOWNLOAD_COMPLETE, downloadComplete);
				appUpdater.addEventListener(DownloadErrorEvent.DOWNLOAD_ERROR, downloadError);
				appUpdater.addEventListener(ErrorEvent.ERROR, updaterError);
				appUpdater.initialize();
			}
		}
		
		private function beforeInstall(event:UpdateEvent):void
		{
			if (isInstallPostponed) {
				event.preventDefault();
				isInstallPostponed = false;
			}
		}
		
		private function updaterInitialized(event:UpdateEvent):void
		{
			this.isFirstRun = event.target.isFirstRun;
			this.applicationName = getApplicationName();
			this.installedVersion = getApplicationVersion();
			
			if(showCheckState && initializeCheckNow) {
				createDialog(UpdateDialog.CHECK_UPDATE);
			} else if (initializeCheckNow) {
				appUpdater.checkNow();
			}
		}
		
		private function statusUpdate(event:StatusUpdateEvent):void
		{
			event.preventDefault();
			if(event.available){
				this.description = getUpdateDescription(event.details);
				this.upateVersion = event.version;
				
				if(!showCheckState) {
					createDialog(UpdateDialog.UPDATE_AVAILABLE);
				} else if (updaterDialog) {
					updaterDialog.applicationName = this.applicationName;
					updaterDialog.installedVersion = this.installedVersion;
					updaterDialog.upateVersion = this.upateVersion;
					updaterDialog.description = this.description
					updaterDialog.updateState = UpdateDialog.UPDATE_AVAILABLE;
				}
			} else if (showNoUpdateState) {
				createDialog(UpdateDialog.NO_UPDATE);
			}
		}
		
		private function statusUpdateError(event:StatusUpdateErrorEvent):void
		{
			event.preventDefault();
			
			if(!updaterDialog) {
				createDialog(UpdateDialog.UPDATE_ERROR);
			} else {
				updaterDialog.updateState = UpdateDialog.UPDATE_ERROR;
				updaterDialog.errorText = event.text;
			}
		}
		
		private function statusFileUpdate(event:StatusFileUpdateEvent):void
		{
			event.preventDefault();
			if(event.available) {
				updaterDialog.updateState = UpdateDialog.UPDATE_DOWNLOADING;
				appUpdater.downloadUpdate();
			} else {
				updaterDialog.updateState = UpdateDialog.UPDATE_ERROR;
			}
		}
		
		private function statusFileUpdateError(event:StatusFileUpdateErrorEvent):void
		{
			event.preventDefault();
			updaterDialog.updateState = UpdateDialog.UPDATE_ERROR;;
			updaterDialog.errorText = event.text;
		}
		
		private function downloadStarted(event:UpdateEvent):void
		{
			updaterDialog.updateState = UpdateDialog.UPDATE_DOWNLOADING;
		}
		
		private function downloadProgress(event:ProgressEvent):void
		{
			updaterDialog.updateState = UpdateDialog.UPDATE_DOWNLOADING;
			var num:Number = (event.bytesLoaded/event.bytesTotal)*100;
			updaterDialog.downloadProgress(num);
		}
		
		private function downloadComplete(event:UpdateEvent):void
		{
			event.preventDefault(); // prevent default install
			updaterDialog.updateState = UpdateDialog.INSTALL_UPDATE;
		}
		
		private function downloadError(event:DownloadErrorEvent):void
		{
			event.preventDefault();
			updaterDialog.updateState = UpdateDialog.UPDATE_ERROR;
			updaterDialog.errorText = event.text;
		}
		
		private function updaterError(event:ErrorEvent):void
		{
			updaterDialog.errorText = event.text;
			updaterDialog.updateState = UpdateDialog.UPDATE_ERROR;
		}
		
		//---------- UpdateDialog Events ----------------//
		
		private function createDialog(state:String):void
		{
			if(!updaterDialog) {
				updaterDialog = new UpdateDialog();
				updaterDialog.isFirstRun = this.isFirstRun;
				updaterDialog.applicationName = this.applicationName;
				updaterDialog.installedVersion = this.installedVersion;
				updaterDialog.upateVersion = this.upateVersion;
				updaterDialog.updateState = state;
				updaterDialog.description = this.description;
				updaterDialog.addEventListener(UpdateDialog.EVENT_CHECK_UPDATE, checkUpdate);
				updaterDialog.addEventListener(UpdateDialog.EVENT_INSTALL_UPDATE, installUpdate);
				updaterDialog.addEventListener(UpdateDialog.EVENT_CANCEL_UPDATE, cancelUpdate);
				updaterDialog.addEventListener(UpdateDialog.EVENT_DOWNLOAD_UPDATE, downloadUpdate);
				updaterDialog.addEventListener(UpdateDialog.EVENT_INSTALL_LATER, installLater);
				updaterDialog.open();
			}
		}
		
		/**
		 * Check for update.
		 * */
		private function checkUpdate(event:Event):void
		{
			appUpdater.checkNow();
		}
		
		/**
		 * Install the update.
		 * */
		private function installUpdate(event:Event):void
		{
			appUpdater.installUpdate();
		}
		
		/**
		 * Install the update.
		 * */
		private function installLater(event:Event):void
		{
			isInstallPostponed = true;
			appUpdater.installUpdate();
			destoryUpdater();
		}
		
		/**
		 * Download the update.
		 * */
		private function downloadUpdate(event:Event):void
		{
			appUpdater.downloadUpdate();
		}
		
		/**
		 * Cancel the update.
		 * */
		private function cancelUpdate(event:Event):void
		{
			appUpdater.cancelUpdate();
			destoryUpdater();
		}
		
		//---------- Destroy All ----------------//
		
		private function destroy():void
		{
			if (appUpdater) {
				appUpdater.configurationFile = configurationFile;
				appUpdater.removeEventListener(UpdateEvent.INITIALIZED, updaterInitialized);
				appUpdater.removeEventListener(StatusUpdateEvent.UPDATE_STATUS, statusUpdate);
				appUpdater.removeEventListener(StatusUpdateErrorEvent.UPDATE_ERROR, statusUpdateError);
				appUpdater.removeEventListener(UpdateEvent.DOWNLOAD_START, downloadStarted);
				appUpdater.removeEventListener(ProgressEvent.PROGRESS, downloadProgress);
				appUpdater.removeEventListener(UpdateEvent.DOWNLOAD_COMPLETE, downloadComplete);
				appUpdater.removeEventListener(DownloadErrorEvent.DOWNLOAD_ERROR, downloadError);
				appUpdater.removeEventListener(UpdateEvent.BEFORE_INSTALL, beforeInstall);
				appUpdater.removeEventListener(ErrorEvent.ERROR, updaterError);
				
				
				appUpdater = null;
			}
			
			destoryUpdater();
		}
		
		private function destoryUpdater():void
		{
			if(updaterDialog) {
				updaterDialog.destroy();
				updaterDialog.removeEventListener(UpdateDialog.EVENT_CHECK_UPDATE, checkUpdate);
				updaterDialog.removeEventListener(UpdateDialog.EVENT_INSTALL_UPDATE, installUpdate);
				updaterDialog.removeEventListener(UpdateDialog.EVENT_CANCEL_UPDATE, cancelUpdate);
				updaterDialog.removeEventListener(UpdateDialog.EVENT_DOWNLOAD_UPDATE, downloadUpdate);
				updaterDialog.removeEventListener(UpdateDialog.EVENT_INSTALL_LATER, installLater);
				updaterDialog.close();
				updaterDialog = null;
			}
			isInstallPostponed = false;
		}
		
		//---------- Utilities ----------------//
		
		/**
		 * Getter method to get the version of the application
		 * Based on Jens Krause blog post: http://www.websector.de/blog/2009/09/09/custom-applicationupdaterui-for-using-air-updater-framework-in-flex-4/
		 *
		 * @return String Version of application
		 *
		 */
		private function getApplicationVersion():String
		{
			var appXML:XML = NativeApplication.nativeApplication.applicationDescriptor;
			var ns:Namespace = appXML.namespace();
			return appXML.ns::version;
		}
		
		/**
		 * Getter method to get the name of the application file
		 * Based on Jens Krause blog post: http://www.websector.de/blog/2009/09/09/custom-applicationupdaterui-for-using-air-updater-framework-in-flex-4/
		 *
		 * @return String name of application
		 *
		 */
		private function getApplicationFileName():String
		{
			var appXML:XML = NativeApplication.nativeApplication.applicationDescriptor;
			var ns:Namespace = appXML.namespace();
			return appXML.ns::filename;
		}
		
		/**
		 * Getter method to get the name of the application, this does not support multi-language.
		 * Based on a method from Adobes ApplicationUpdateDialogs.mxml, which is part of Adobes AIR Updater Framework
		 * Also based on Jens Krause blog post: http://www.websector.de/blog/2009/09/09/custom-applicationupdaterui-for-using-air-updater-framework-in-flex-4/
		 *
		 * @return String name of application
		 *
		 */
		private function getApplicationName():String
		{
			var applicationName:String;
			var xmlNS:Namespace=new Namespace("http://www.w3.org/XML/1998/namespace");
			var appXML:XML=NativeApplication.nativeApplication.applicationDescriptor;
			var ns:Namespace=appXML.namespace();
			
			// filename is mandatory
			var elem:XMLList=appXML.ns::filename;
			
			// use name is if it exists in the application descriptor
			if ((appXML.ns::name).length() != 0)
			{
				elem=appXML.ns::name;
			}
			
			// See if element contains simple content
			if (elem.hasSimpleContent())
			{
				applicationName=elem.toString();
			}
			
			return applicationName;
		}
		
		/**
		 * Helper method to get release notes, this does not support multi-language.
		 * Based on a method from Adobes ApplicationUpdaterDialogs.mxml, which is part of Adobes AIR Updater Framework
		 * Also based on Jens Krause blog post: http://www.websector.de/blog/2009/09/09/custom-applicationupdaterui-for-using-air-updater-framework-in-flex-4/
		 *
		 * @param detail Array of details
		 * @return String Release notes depending on locale chain
		 *
		 */
		protected function getUpdateDescription(details:Array):String
		{
			var text:String="";
			
			if (details.length == 1)
			{
				text=details[0][1];
			}
			return text;
		}
	}
}