#---------------------------------------------------------------------------------------------------------
#	Trackmate Batch Analysis
#	-----------------------
#	Author: Fazeli E, Roy NH, Follain G et al. Automated cell tracking using StarDist and TrackMate. F1000Research 2020, 9:1279 (https://doi.org/10.12688/f1000research.27019.2)
#	Modified by: Marlies Verschuuren - marlies.verschuuren@uantwerpne.be
#	Date Created: 		2021 - 03 - 01
#	Date Last Modified:	2021 - 03 - 02
#	
#---------------------------------------------------------------------------------------------------------

#------------------------------------------------Libraries-----------------------------------------------
from fiji.plugin.trackmate import Model
from ij import WindowManager
from fiji.plugin.trackmate import Settings
from fiji.plugin.trackmate import TrackMate
from fiji.plugin.trackmate import SelectionModel
from fiji.plugin.trackmate import Logger
from fiji.plugin.trackmate.detection import DetectorKeys
from fiji.plugin.trackmate.detection import LogDetectorFactory
from fiji.plugin.trackmate.tracking.sparselap import SparseLAPTrackerFactory
from ij import IJ, WindowManager
from fiji.plugin.trackmate.tracking import LAPUtils
import fiji.plugin.trackmate.visualization.hyperstack.HyperStackDisplayer as HyperStackDisplayer
import fiji.plugin.trackmate.visualization.PerTrackFeatureColorGenerator as PerTrackFeatureColorGenerator
import fiji.plugin.trackmate.features.FeatureFilter as FeatureFilter
import sys
import csv
import shutil 
import os
from fiji.plugin.trackmate.providers import SpotAnalyzerProvider
from fiji.plugin.trackmate.providers import EdgeAnalyzerProvider
from fiji.plugin.trackmate.providers import TrackAnalyzerProvider
import fiji.plugin.trackmate.extra.spotanalyzer.SpotMultiChannelIntensityAnalyzerFactory as SpotMultiChannelIntensityAnalyzerFactory
import fiji.plugin.trackmate.features.track.TrackDurationAnalyzer as TrackDurationAnalyzer
import fiji.plugin.trackmate.features.track.TrackSpeedStatisticsAnalyzer as TrackSpeedStatisticsAnalyzer
import fiji.plugin.trackmate.features.track.TrackIndexAnalyzer as TrackIndexAnalyzer
import fiji.plugin.trackmate.features.edges.EdgeTargetAnalyzer as EdgeTargetAnalyzer
import fiji.plugin.trackmate.features.edges.EdgeVelocityAnalyzer as EdgeVelocityAnalyzer
import fiji.plugin.trackmate.features.edges.EdgeTimeLocationAnalyzer as EdgeTimeLocationAnalyzer
import fiji.plugin.trackmate.features.SpotFeatureCalculator as SpotFeatureCalculator
import fiji.plugin.trackmate.features.spot.SpotContrastAndSNRAnalyzer as SpotContrastAndSNRAnalyzer
import fiji.plugin.trackmate.features.spot.SpotIntensityAnalyzerFactory as SpotIntensityAnalyzerFactory
import fiji.plugin.trackmate.features.spot.SpotRadiusEstimatorFactory as SpotRadiusEstimatorFactory
import fiji.plugin.trackmate.features.spot.SpotMorphologyAnalyzerFactory as SpotMorphologyAnalyzerFactory

import fiji.plugin.trackmate.action.ExportStatsToIJAction as ExportStatsToIJAction;


from fiji.plugin.trackmate.action import CaptureOverlayAction
from ij.io import FileSaver

import os
from ij import IJ, ImagePlus
from ij.gui import GenericDialog
from ij.measure import Calibration
import java.io.File as File
import java.util.ArrayList as ArrayList


#------------------------------------------------Functions-----------------------------------------------
def run():
	srcDir = IJ.getDirectory("Input_directory")
	dstDir = os.path.join(srcDir,"TrackMateAnalysis")
	if not os.path.exists(dstDir):
		os.makedirs(dstDir)

	#Get Files in top directory
	files = []
	for (dirpath, dirnames, filenames) in os.walk(srcDir):
   		files.extend(filenames)
   		break

	#Loop over every file
	for f in files:
		if f.endswith(".tif"):
			process(srcDir, dstDir, f)
	IJ.log("Analyis Done")
	IJ.selectWindow("Log");
	path=os.path.join(dstDir,"Log.txt")
	IJ.saveAs("Text", path);
	
def process(srcDir, dstDir, fileName):
    # Opening the image
	path=os.path.join(srcDir, fileName)
	IJ.log("Open image file: " + path)
	imp = IJ.openImage(os.path.join(srcDir, fileName))
	cal = imp.getCalibration()
	dims = imp.getDimensions() # default order: XYCZT
	if (dims[4] == 1):
		imp.setDimensions(1, 1, dims[3]) 
  	
    # Start the tracking
	model = Model()
  	
  	# Read the image calibration
	model.setPhysicalUnits(cal.getUnit(),cal.getTimeUnit() )
	
    # Settings
	settings = Settings()
	settings.setFrom(imp)
       
	# Configure detector
	settings.detectorFactory = LogDetectorFactory()
	settings.detectorSettings = {DetectorKeys.KEY_RADIUS: 2.,
                                 DetectorKeys.KEY_TARGET_CHANNEL: 3,
                                 DetectorKeys.KEY_THRESHOLD : 0.001,
                                 DetectorKeys.KEY_DO_SUBPIXEL_LOCALIZATION: False,
                                 DetectorKeys.KEY_DO_MEDIAN_FILTERING: False,}
    

    # Configure tracker
	settings.trackerFactory = SparseLAPTrackerFactory()
	settings.trackerSettings = LAPUtils.getDefaultLAPSettingsMap() # almost good enough
	settings.trackerSettings['LINKING_MAX_DISTANCE']    = LINKING_MAX_DISTANCE
	settings.trackerSettings['ALLOW_GAP_CLOSING']   	= ALLOW_GAP_CLOSING
	settings.trackerSettings['GAP_CLOSING_MAX_DISTANCE']= GAP_CLOSING_MAX_DISTANCE
	settings.trackerSettings['MAX_FRAME_GAP']    		= int(MAX_FRAME_GAP)
	settings.trackerSettings['ALLOW_TRACK_SPLITTING']   = ALLOW_TRACK_SPLITTING
	settings.trackerSettings['SPLITTING_MAX_DISTANCE']  = SPLITTING_MAX_DISTANCE
	settings.trackerSettings['ALLOW_TRACK_MERGING']     = False

	# Spot analyzer: we want the multi-C intensity analyzer.
	settings.addSpotAnalyzerFactory(SpotMultiChannelIntensityAnalyzerFactory() )
	# Edge Analyzer
	edgeAnalyzerProvider = EdgeAnalyzerProvider()
	for  key in edgeAnalyzerProvider.getKeys():
		print( key )
		settings.addEdgeAnalyzer( edgeAnalyzerProvider.getFactory( key ) )
 	# Track Analyzer
	trackAnalyzerProvider = TrackAnalyzerProvider()
	for key in trackAnalyzerProvider.getKeys():
		print( key )
		settings.addTrackAnalyzer( trackAnalyzerProvider.getFactory( key ) )
	
#-------------------
# Instantiate plugin
#-------------------
	IJ.log("Spot detection and Tracking")   		
	trackmate = TrackMate(model, settings)
#--------
# Process
#--------
	ok = trackmate.checkInput()
	if not ok:
		sys.exit(str(trackmate.getErrorMessage()))
	ok = trackmate.process()
	if not ok:
		sys.exit(str(trackmate.getErrorMessage()))
       
#----------------
# Display results
#----------------
	IJ.log('Found ' + str(model.getTrackModel().nTracks(True)) + ' tracks.')
	IJ.log("Save Overlay")
	
	selectionModel = SelectionModel(model)
	color = PerTrackFeatureColorGenerator(model, 'TRACK_INDEX')
	player =  HyperStackDisplayer(model, selectionModel, imp)
	player.setDisplaySettings(player.KEY_DISPLAY_SPOT_NAMES,True)
	player.setDisplaySettings(player.KEY_TRACK_COLORING, color)
	player.render()
	player.refresh()
	capture = CaptureOverlayAction.capture(trackmate, -1, imp.getNFrames()) 
	path=os.path.join(dstDir,fileName+"_Overlay.tif")
	FileSaver(capture).saveAsTiff(path)
	imp.close()

	IJ.log("Save Results")   		
	ExportStatsToIJAction(selectionModel).execute(trackmate)
	IJ.selectWindow("Links in tracks statistics");
	path=os.path.join(dstDir,fileName+"_Links.txt")
	IJ.saveAs("Results", path)
	IJ.run("Close")
	IJ.selectWindow("Spots in tracks statistics");
	path=os.path.join(dstDir,fileName+"_Spots.txt")
	IJ.saveAs("Results", path)
	IJ.run("Close")
	IJ.selectWindow("Track statistics");
	path=os.path.join(dstDir,fileName+"_Tracks.txt")
	IJ.saveAs("Results", path)
	IJ.run("Close") 
	IJ.run("Collect Garbage");

#------------------------------------------------Main-----------------------------------------------
#GUI
IJ.log("Batch analysis TrackMate")
gd = GenericDialog("Tracking settings")
gd.addNumericField("Linking: max distance", 20, 1)
gd.addCheckbox("Gap closing: ", True)
gd.addNumericField("Gap closing: max distance", 20, 1)
gd.addNumericField("Gap closing: max frame gap", 2, 1)
gd.addCheckbox("Track splitting: ", True)
gd.addNumericField("Track splitting: max distance", 20, 1)
gd.showDialog()

LINKING_MAX_DISTANCE 	= gd.getNextNumber()
ALLOW_GAP_CLOSING		= gd.getNextBoolean()
GAP_CLOSING_MAX_DISTANCE= gd.getNextNumber()
MAX_FRAME_GAP			= gd.getNextNumber()
ALLOW_TRACK_SPLITTING 	= gd.getNextBoolean()
SPLITTING_MAX_DISTANCE 	= gd.getNextNumber()

IJ.log("------------------Settings----------------")
IJ.log("Linking Max Distance: "+ str(LINKING_MAX_DISTANCE))
IJ.log("Allow Gap Closing: "+ str(ALLOW_GAP_CLOSING))
IJ.log("Gap Closing Max Distance: "+ str(GAP_CLOSING_MAX_DISTANCE))
IJ.log("Gap Closing Max Frame Gap: "+ str(MAX_FRAME_GAP))
IJ.log("Allow Track Splitting: "+ str(ALLOW_TRACK_SPLITTING))
IJ.log("Track Splitting Max Distance: "+ str(SPLITTING_MAX_DISTANCE))

#Run
IJ.log("------------------Analysis----------------")
run()