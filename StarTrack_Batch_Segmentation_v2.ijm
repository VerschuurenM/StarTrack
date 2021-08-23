//--------------------------------------------------------------------------
//StarTrack: Accurate nuclei detection to facilitate tracking
//		Stardist [1] is used to accurately detect nuclei in time series.
//		Morphological and intensity measurements are exported as well as binary masks in which the center of each nucleus is represented as a dot.
// 
// 		[1] Uwe Schmidt, Martin Weigert, Coleman Broaddus, and Gene Myers. Cell Detection with Star-convex Polygons. International Conference on Medical Image Computing and Computer-Assisted Intervention (MICCAI), Granada, Spain, September 2018.
//
//		Author: Marlies Verschuuren -  marlies.verschuuren@uantwerpen.be
// 		Last Modified: 2021 04 15
//--------------------------------------------------------------------------

//Variables
var file_types 			= newArray(".tif",".tiff",".nd2",".ids",".jpg",".mvd2",".czi");	
var filters 			= newArray("Gaussian","Median");			
var suffix				= ".tif";									//	suffix for specifying the file type
var pixel_size			= 0.37;
var micron				= getInfo("micrometer.abbreviation");		// 	micro symbol

var nuclei_channel		= 1;
var nuclei_clahe		= true;
var nuclei_filter		= "Gaussian"
var nuclei_filter_scale	= 4;										// 	nuclei_filter_scale radius for nuclei
var nuclei_min_area		= 50;										//	calibrated min nuclear size (in µm2)
var nuclei_probability	= 0.5;										//	minimal nuclei_probability for Stardist nuclei detection
var nuclei_overlap 		= 0.3;										//	nuclei_overlap amount tolerated for Stardist nuclei detection
var nuclei_min_int		= 30;

var mask_spot_radius=2;												//	calibrated area spots in masks (in µm2)


/// Intensity DAPI as filter? 


//------------------------- Macro -------------------------//
macro "[I] Install Macro"{
	// Only works on my personal drive 
	run("Install...", "install=[/data/CBH/mverschuuren/ACAM/CBH_CellSystems_FreyaMolenberghs/Trackmate/TrackMate_Segmentation_v2.ijm]");
}

macro "Split File Action Tool - C888 R0077 R9077 R9977 R0977"{
	setBatchMode(true);
	splitRegions();
	setBatchMode("exit and display");
}

macro "Setup Action Tool - C888 T5f16S"{
	setup();
}

macro "Segment Nuclei Action Tool - C888 H00f5f8cf3f0800 Cf88 V4469"{
	erase(0);
	setBatchMode(true);
	dir = getInfo("image.directory");
	output_dir = dir+"Output"+File.separator;
	masks_dir = dir+"Masks"+File.separator;
	if(!File.exists(output_dir)){
		File.makeDirectory(output_dir);
	}
	if(!File.exists(masks_dir)){
		File.makeDirectory(masks_dir);
	}
	idStack=getImageID();
	getPixelSize(unit, pixelWidth, pixelHeight);
	if(unit!=micron){
		run("Properties...", " unit="+micron+" pixel_width="+pixel_size+" pixel_height="+pixel_size);
	}
	else{
		pixel_size = pixelWidth;
	}
	segmentFrames(idStack,0,0);
	roiManager("show all without labels");
	setBatchMode("exit and display");
	run("Tile");
}

macro "Analyse Single Image Action Tool - C888 T5f161"{
	erase(0);
	setBatchMode(true);
	dir = getInfo("image.directory");
	output_dir = dir+"Output"+File.separator;
	masks_dir = dir+"Masks"+File.separator;
	if(!File.exists(output_dir)){
		File.makeDirectory(output_dir);
	}
	if(!File.exists(masks_dir)){
		File.makeDirectory(masks_dir);
	}
	idStack=getImageID();
	getPixelSize(unit, pixelWidth, pixelHeight);
	if(unit!=micron){
		run("Properties...", " unit="+micron+" pixel_width="+pixel_size+" pixel_height="+pixel_size);
	}
	else{
		pixel_size = pixelWidth;
	}
	segmentFrames(idStack,1,0);
	setBatchMode("exit and display");
}

macro "Batch Analysis Action Tool - C888 T5f16#"{
	erase(0);
	setBatchMode(true);
	
	dir = getDirectory("Choose input directory");
	output_dir = dir+"Output"+File.separator;
	masks_dir = dir+"Masks"+File.separator;
	if(!File.exists(output_dir)){
		File.makeDirectory(output_dir);
	}
	if(!File.exists(masks_dir)){
		File.makeDirectory(masks_dir);
	}

	list = getFileList(dir);
	for(i=0;i<list.length;i++){
		path=dir+list[i];
		if(endsWith(path,suffix)){		
			print("Image: "+(i+1)+"/"+list.length);
			run("Bio-Formats Importer", "open=["+path+"] color_mode=Default open_files view=Hyperstack stack_order=XYCZT");
			idStack=getImageID();
			getPixelSize(unit, pixelWidth, pixelHeight);
			if(unit!=micron){
				run("Properties...", " unit="+micron+" pixel_width="+pixel_size+" pixel_height="+pixel_size);
			}
			else{
				pixel_size = pixelWidth;
			}
			segmentFrames(idStack,1,1);
		}
	}
	if(isOpen("Log")){
		selectWindow("Log");
		saveAs("txt",output_dir+"Log.txt");
	}
	setBatchMode("exit and display");
}

macro "Toggle Overlay Action Tool - Caaa O11ee"
{
	toggleOverlay();
}

macro "[t] Toggle Overlay"
{
	toggleOverlay();
}

//------------------------- Functions -------------------------//
function setup()
{
	setOptions();
	Dialog.create("TrackMate - Nuclei detection");
	Dialog.setInsets(0,0,0);
	Dialog.addChoice("Image Type", file_types, suffix);
	Dialog.setInsets(0,0,0);
	Dialog.addNumber("Pixel Size", pixel_size, 3, 5, micron+" (only if not calibrated)");
	Dialog.setInsets(0,0,0);
	Dialog.addNumber("Nuclear Channel", nuclei_channel, 0, 4, "");
	Dialog.setInsets(0,0,0);
	Dialog.addCheckbox("CLAHE", true);
	Dialog.setInsets(0,0,0);
	Dialog.addChoice("Filter", filters, nuclei_filter);
	Dialog.setInsets(0,0,0);
	Dialog.addNumber("Radius Filter", nuclei_filter_scale, 0, 4, "");
	Dialog.setInsets(0,0,0);
	Dialog.addSlider("Probability (StarDist)", 0, 1, nuclei_probability);
	Dialog.setInsets(0,0,0);
	Dialog.addSlider("Overlap (StarDist)", 0, 1, nuclei_overlap);
	Dialog.setInsets(0,0,0);
	Dialog.addNumber("Min nuclear area", nuclei_min_area, 0, 5, micron+"2");
	Dialog.setInsets(0,0,0);
	Dialog.addNumber("Min nuclear int", nuclei_min_int, 0, 5, "");
	Dialog.setInsets(0,0,0);
	Dialog.addNumber("Mask spot size", mask_spot_radius, 0, 5, micron+"2");
	Dialog.show();
	
	print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%");
	
	suffix							= Dialog.getChoice();		print("Image type:",suffix);
	pixel_size						= Dialog.getNumber(); 		print("Pixel size:",pixel_size);
	nuclei_channel 					= Dialog.getNumber();		print("Nuclear channel:",nuclei_channel);
	nuclei_clahe					= Dialog.getCheckbox();		print("CLAHE: ",nuclei_clahe);
	nuclei_filter					= Dialog.getChoice();		print("Filter:", nuclei_filter); 
	nuclei_filter_scale				= Dialog.getNumber();		print("Filter scale:",nuclei_filter_scale);
	nuclei_probability 				= Dialog.getNumber();		print("Probability:",nuclei_probability);
	nuclei_overlap 					= Dialog.getNumber();		print("Overlap:",nuclei_overlap);
	nuclei_min_area					= Dialog.getNumber();		print("Min nuclear area (µm2):", nuclei_min_area);
	nuclei_min_int					= Dialog.getNumber();		print("Min nuclear int: ", nuclei_min_int);
	mask_spot_radius				= Dialog.getNumber();		print("Mask spot radius (µm):", mask_spot_radius);
}

function segmentFrames(idStack,all,batch){
	selectImage(idStack);

	//Adapt title
	nameStack = getTitle();
	prefix = substring(nameStack,0,lastIndexOf(nameStack,suffix));;

	//Get Dimensions
	getDimensions(widthImage, heightImage, channels, slices, frames);
	getVoxelSize(width, height, depth, unit);
	interval=Stack.getFrameInterval();
	Stack.getUnits(X, Y, Z, Time, Value);
	
	//Create Reference Image
	newImage("HyperStack","8-bit", widthImage, heightImage,1,slices,frames);
	rename("Ref");
	idStackRef=getImageID();
	setVoxelSize(width, height, depth, unit);
	Stack.setFrameInterval(interval);
	Stack.setUnits(X, Y, Z, Time, Value);

	//Set frame range
	if(all==0){
		selectImage(idStack);
		Stack.getPosition(channel, slice, frame);
		print(frame);
		frame_start=frame;
		frame_end=frame;
	}else if (all==1){
		frame_start=1;
		frame_end=frames;
	}

	//Segment Frames + Make Reference mask
	for (f = frame_start; f <= frame_end; f++) {
		print("frame:"+f+"/"+frames);
		
		//File name
		nuclei_roi_set = output_dir+prefix+"_frame_"+f+"_nuclei_roi_set.zip";
		nuclei_results = output_dir+prefix+"_frame_"+f+"_nuclei_results.txt";
		
		//Duplicate Frame + Preprocess
		selectImage(idStack);
		run("Duplicate...", "title=Frame duplicate frames="+f);
		idFrame=getImageID();
		run("Duplicate...", "title=Nuc duplicate channels="+nuclei_channel);
		idNuc=getImageID();
		if(nuclei_clahe){
			run("Enhance Local Contrast (CLAHE)", "blocksize=100 histogram=256 maximum=3 mask=*None* fast_(less_accurate)");
		}
		if(nuclei_filter=="Gaussian"){
			run("Gaussian Blur...", "sigma="+nuclei_filter_scale);
		}else if(nuclei_filter=="Median"){
			run("Median...", "radius="+nuclei_filter_scale);
		}
		
		//Stardist nuclei detection
		setBatchMode("exit and display");
		run("Command From Macro", "command=[de.csbdresden.stardist.StarDist2D], args=['input':'Nuc', 'modelChoice':'Versatile (fluorescent nuclei)', 'normalizeInput':'true', 'percentileBottom':'1.0', 'percentileTop':'99.8', 'probThresh':'"+nuclei_probability+"', 'nmsThresh':'"+nuclei_overlap+"', 'outputType':'ROI Manager', 'nTiles':'1', 'excludeBoundary':'2', 'roiPosition':'Automatic', 'verbose':'false', 'showCsbdeepProgress':'false', 'showProbAndDist':'false'], process=[false]");
		setBatchMode(true);
		
		//Resolve overlapping ROIs
		newImage("Mask", "8-bit black", widthImage, heightImage, 1);
		setVoxelSize(width, height, depth, unit);
		idMask = getImageID;
		nr_rois = roiManager("count");
		for(r = 0; r < nr_rois; r++){
			selectImage(idMask);
			setColor(255);
			roiManager("select",r);
			run("Enlarge...", "enlarge=1 pixel");
			run("Clear");
			run("Enlarge...", "enlarge=-1 pixel");
			run("Fill");
		}
		roiManager("Deselect");
		roiManager("reset");
		setThreshold(1,255);
		run("Convert to Mask");
		run("Analyze Particles...", "size="+nuclei_min_area+"-infinity circularity=0.00-1.00 show=Nothing exclude clear include add");

		//Create reference image with spots
		nr_rois = roiManager("count");
		run("Set Measurements...", "centroid mean redirect=None decimal=4");
		for(r = 0; r < nr_rois; r++){
			selectImage(idFrame);
			Stack.setChannel(nuclei_channel);
			roiManager("select",r);
			roiManager("measure");
			if(getResult("Mean", 0) < nuclei_min_int){
				roiManager("delete");
				nr_rois = roiManager("count");
				r--;
			}else {
				Mx=getResult("X", 0);
				My=getResult("Y", 0);
				Mx=Mx/width;
				My=My/height;
				selectImage(idStackRef);
				setSlice(f);
				radius=mask_spot_radius/width;
				makeOval(Mx-radius, My-radius, radius*2, radius*2);
				run("Enlarge...", "enlarge=1 pixel");
				run("Clear","slice");
				run("Enlarge...", "enlarge=-1 pixel");
				setColor(r+1);
				run("Fill","slice");
			}
			roiManager("deselect");
			run("Clear Results");
		}
		for(r = 0; r < nr_rois; r++){
			roiManager("select",r);
			if(r<9)roiManager("Rename","000"+(r+1));
			else if(r<99)roiManager("Rename","00"+(r+1));	
			else if(r<999)roiManager("Rename","0"+(r+1));	
			else roiManager("Rename",r+1);
		}
		roiManager("deselect");
		roiManager("Save",nuclei_roi_set);
		run("Set Measurements...", "  area centroid perimeter shape feret's mean median standard min redirect=None decimal=4");
		rmc = roiManager("count");
		selectImage(idFrame);
		for(c=1;c<=channels;c++)
		{
			setSlice(c);
			roiManager("deselect");
			roiManager("Measure");
		}
		sortResults();
		updateResults;
		saveAs("Measurements",nuclei_results);
		selectImage(idNuc);close();
		selectImage(idFrame);close();
		selectImage(idMask); close();
		if(all==1){
			roiManager("reset");
			erase(0);
		}
	}
	if(all==1){
		selectImage(idStack);
		run("Split Channels");	
		run("Merge Channels...", "c1=[C1-"+nameStack+"] c2=[C2-"+nameStack+"] c3=[Ref] create");
		idStackSave=getImageID();
		Stack.setChannel(1);
		run("Grays");
		Stack.setChannel(3);
		run("Red");
		setMinAndMax(0, 1);
		Stack.setActiveChannels("101");
		saveAs(".tif", masks_dir+prefix+"_Mask.tif");
	}
	if(batch){
		selectImage(idStackSave);close();
		erase(0);
	}
}

function sortResults()
{
	resultLabels = getResultLabels();
	matrix = results2matrix(resultLabels);
	matrix2results(matrix,resultLabels,channels);
}

function getResultLabels()
{
	selectWindow("Results");
	ls 				= split(getInfo(),'\n');
	rr 				= split(ls[0],'\t'); 
	nparams 		= rr.length-1;			
	resultLabels 	= newArray(nparams);
	for(j=1;j<=nparams;j++){resultLabels[j-1]=rr[j];}
	return resultLabels;
}

function results2matrix(resultLabels)
{
	h = nResults;
	w = resultLabels.length;
	newImage("Matrix", "32-bit Black",w, h, 1);
	matrix = getImageID;
	for(j=0;j<w;j++)
	{
		for(r=0;r<h;r++)
		{
			v = getResult(resultLabels[j],r);
			selectImage(matrix);
			setPixel(j,r,v);
		}
	}
	run("Clear Results");
	return matrix;
}

function matrix2results(matrix,resultLabels,channels)
{
	selectImage(matrix);
	w = getWidth;
	h = getHeight;
	for(c=0;c<channels;c++)
	{
		start = c*h/channels;
		end = c*h/channels+h/channels;
		for(k=0;k<w;k++)
		{
			for(j=start;j<end;j++)
			{
				selectImage(matrix);
				p = getPixel(k,j);
				setResult(resultLabels[k]+"_MC"+c+1,j-start,p); // MC for measurement channel
			}
		}
	}
	selectImage(matrix); close;
	updateResults;
}

function splitRegions(){
	erase(1);
	Dialog.create("Split File...");
	Dialog.addString("Destination Directory Name","Export",25);
	Dialog.addString("Add a prefix","",25);
	Dialog.addChoice("Import format",file_types,".mvd2");
	Dialog.addChoice("Export format",file_types,suffix);
	Dialog.addNumber("Series",40);
	Dialog.show;
	dest 		= Dialog.getString;
	pre			= Dialog.getString;
	ext			= Dialog.getChoice;
	suffix 		= Dialog.getChoice;
	series		= Dialog.getNumber;

	dir = getDirectory("");
	file_list = getFileList(dir);
	destination_dir = dir+dest+File.separator;
	File.makeDirectory(destination_dir);
	
	for(i=0;i<file_list.length;i++){
		path = dir+file_list[i];
		if(endsWith(path,ext)){
			for(s=1;s<=series;s++){
				print("Serie: "+s);
				run("Bio-Formats Importer", "open=["+path+"] color_mode=Default view=Hyperstack series_"+s);
				id = getImageID;
				title = getTitle; 
				name=replace(title, "/", "_");
				saveAs(suffix,destination_dir+pre+name+suffix);
				selectImage(id);
				close();
			}
		}
	}
	print("Done");
}

function toggleOverlay(){	
	run("Select None"); 
	roiManager("deselect");
	roiManager("Show All without labels");
	if(Overlay.size == 0)run("From ROI Manager");
	else run("Remove Overlay");
}


function setOptions(){
	run("Options...", "iterations=1 count=1");
	run("Colors...", "foreground=white correct_background=black selection=yellow");
	run("Overlay Options...", "stroke=red width=1 fill=none");
	setBackgroundColor(0, 0, 0);
	setForegroundColor(255,255,255);
}

function erase(all){
	if(all){print("\\Clear");run("Close All");}
	run("Clear Results");
	roiManager("reset");
	run("Collect Garbage");
}