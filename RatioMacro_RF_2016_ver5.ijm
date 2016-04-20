// Calculates ratio images and onionizes them and scores them

// clean the slate 
run("Close All");

//dialouge to get some set points

  //variable definitions
  sigmaConstrain=2;
  qualityCutoff=0.8;
  nuberofOnionZones = 0;
  doMaxRecording = false;

  //The dialouge
  Dialog.create("Ratio analysis");

  Dialog.addNumber("Divide only pixels within Sigma from mean, Sigma:", 2);
  Dialog.addNumber("Quality Cutoff [0-1]:", 0.8);
  Dialog.addNumber("Number of Zones in the onion analyzis [0 = max]:", 0);

  Dialog.show();
  //fetching the input 
  title = Dialog.getString();
  
  qualityCutoff = Dialog.getNumber();
  sigmaConstrain = Dialog.getNumber();
  nuberofOnionZones = Dialog.getNumber();
  if(nuberofOnionZones==0){
  	doMaxRecording=true;
  }


//set measurements to be used 
run("Set Measurements...", "area mean standard min median stack display redirect=None decimal=3");
//set binary options
run("Options...", "iterations=1 count=1 black edm=Overwrite do=Nothing");
		
parentDir = getDirectory("Choose a Directory "); //open dialog to select master folder
filesAndFolders = listFilesAndFolders(parentDir, "lsm");  //get subFolders containing images
File.makeDirectory(parentDir+"Results/");  //create directory to put results moved to listFolders
folderMark = "folder:_";
fileMark = "file:_";
files = newArray("files");
folders = newArray("folders");
print(filesAndFolders.length );
for(i=0; i<filesAndFolders.length ; i++){
	if(startsWith(filesAndFolders[i], fileMark)){
		newFile =  substring(filesAndFolders[i], lengthOf(fileMark));
		files = Array.concat(files, newFile);
		print("File :" + filesAndFolders[i]);
	}
	else{
		newFolder =  substring(filesAndFolders[i], lengthOf(folderMark));
		folders = Array.concat(folders, newFolder);
		print(" Folder :" + filesAndFolders[i]);
	}
}

for(i=1; i<folders.length ; i++){
	File.makeDirectory(parentDir+"Results/"+substring(folders[i], lengthOf(parentDir)));
}

  maxResultsTitle = "MaxMeanResults";
  maxResultsTempTitle = "["+maxResultsTitle+"]";
  f = maxResultsTempTitle;
  if (isOpen(maxResultsTitle)){
     print(f, "\\Update:"); // clears the window
  	}
  else{
     run("Text Window...", "name="+maxResultsTempTitle+" width=72 height=8 menu");
  }
  print(f, "Folder \t File \t Slize \t Number of zones \t Mean of Zones:");	//print legend

  maxClusterResultsTitle = "MaxClusterResults";
  maxClusterResultsTempTitle = "["+maxClusterResultsTitle+"]";
  g = maxClusterResultsTempTitle;
  if (isOpen(maxClusterResultsTitle)){
     print(g, "\\Update:"); // clears the window
  	}
  else{
     run("Text Window...", "name="+maxClusterResultsTempTitle+" width=72 height=8 menu");
  }
  print(g, "Folder \t File \t Slize \t Number of Clusters \t SumArea of Clusters:");	//print legend
print("number of files to be analyzed  =" + lengthOf(files));
for (fileNumber=1; fileNumber<lengthOf(files); fileNumber++){ //loop to iterate through the files

	run("Clear Results"); //reset results 
	
	activeFolder = substring(files[fileNumber], lengthOf(parentDir), lastIndexOf(files[fileNumber], "/")+1);
	activePath = parentDir+"Results/"+activeFolder;
	print("Saving to folder: " + activePath);
 	open(files[fileNumber]); //run("Image Sequence...", "open=["+files[fileNumber]+"]"); //open image
 	originaSlices = nSlices();
 	run("Stack to Hyperstack...", "order=xyczt(default) channels=2 slices="+originaSlices/2+" frames=1 display=Color");

		hyperOriginal = getImageID();
		title=getTitle();
		
		stringResult = split(title, ".");
		titleCut=stringResult[0]; //get file name without .ome or .tif
		run("Remove Outliers...", "radius=1 threshold=50 which=Bright stack"); //remove shot noize
		IDs= newArray(2); //array to hold folder list
		IDs = splitChanels(hyperOriginal, titleCut);
		greenID = IDs[0];
		redID= IDs[1];

		setOption("Display label", true);

		maskID = createMask(redID);
		selectImage(maskID);		
		saveAs("Tiff", activePath+titleCut+"Mask");  

		print("normalizing green");
		normalGreenID = normalize(greenID, maskID);
		selectImage(normalGreenID);
		saveAs("Tiff",activePath+titleCut+"GreenNucleiNormalized");
		
		print("normalizing red");
		normalRedID = normalize(redID, maskID);
		selectImage(normalRedID);
		saveAs("Tiff",activePath+titleCut+"redNucleiNormalized");
		
		//create ratio image, set constraints based average SD, last value (X) gives cutoff = meanBg + X*SD, 2 is giving nice results for now
		print("creating ratio");
		ratioID = divideWithConstraints(normalGreenID, normalRedID, maskID, sigmaConstrain);
		selectImage(ratioID);
		saveAs("Tiff",activePath+titleCut+"Ratio");	

		//check that there is sufuicient data to work with 
		

		setBatchMode(false);
		selectImage(maskID);
		
		nucVoxels = 0;
		
		for(maskSlice=1;maskSlice < nSlices() ;maskSlice++){
			selectImage(maskID);
			setSlice(maskSlice);
			getRawStatistics(nPixels, mean, min, max, std, histogram);
			nucVoxels = nucVoxels + histogram[255];
		}
		selectImage(ratioID);
		run("Statistics");
		ratioVoxels = getResult("Voxels");
		qualityRatio = (ratioVoxels/nucVoxels);
		print("nucVoxels ="+ nucVoxels +" ratioVoxels = "+ratioVoxels+ " ratio = "+qualityRatio);
		if( (qualityRatio > qualityCutoff) || (isNaN(ratioVoxels / nucVoxels)) ){ 
			print("image quality to low to process images further");
		}
		else{
			//log ratio image to make the representation linear
			print("loging ratio");
			ratioLogID = logImage(ratioID);
			selectImage(ratioLogID);
			saveAs("Tiff",activePath+titleCut+"LogRatio");	


			//ugly hack to make a stack to hold plots
			selectImage(maskID);
			run("Duplicate...", "title=plotStack duplicate");
			run("RGB Color");
			plotStackID = getImageID();

		
			//make Onion measurements
			print("onionizing");
			distanceMapID = onionSegment(ratioID, maskID, fileNumber, nuberofOnionZones, doMaxRecording, 0.02, activeFolder, titleCut, f, 1);
			selectImage(distanceMapID);
			run("3-3-2 RGB");
			saveAs("Tiff",activePath+titleCut+"DistanceMapID");	

			selectWindow("Results");
			saveAs("Results",activePath+"TotalOnionResults.xls");
		

			//make cluster analysis 
			clusterESMaskID = clusterAnalysisES(maskID, normalRedID, 0.05, 10, 0); //clusterAnalysisES(mask, inputImage, cutoff, minSize, useScale)
			selectImage(clusterESMaskID);
			run("Invert", "stack");
			saveAs("Tiff",activePath+titleCut+"clusterESMask");

			selectWindow("Summary of ClusterAnalysisES");
			saveAs("Text",  activePath+"SummaryClusterESAnalysis.csv");
			run("Close");
		
			selectWindow("Results");
			saveAs("Results",activePath+"TotalClusterESResults.xls");
	
			//make cluster analysis top
			clusterTopMaskID = clusterAnalysisRF(ratioLogID, 1, 0.1, 10);
			selectImage(clusterTopMaskID);
			run("Invert", "stack");
			saveAs("Tiff",activePath+titleCut+"clusterTopMask");

			selectWindow("Summary of ClusterAnalysisTop");
			saveAs("Text",  activePath+"SummaryClusterTopAnalysis.csv");
			run("Close");
		
			selectWindow("Results");
			saveAs("Results",activePath+"TotalClusterTopResults.xls");
	
			//make cluster analysis bottom
			clusterBottomMaskID = clusterAnalysisRF(ratioLogID, 0, 0.1, 10);
			selectImage(clusterBottomMaskID);
			run("Invert", "stack");
			saveAs("Tiff",activePath+titleCut+"clusterBottomMask");
	
			selectWindow("Summary of ClusterAnalysisBottom");
			saveAs("Text",  activePath+"SummaryClusterBottomAnalysis.csv");
			run("Close");
		
			selectWindow("Results");
			saveAs("Results",activePath+"TotalClusterBottomResults.xls");
	
			selectImage(clusterESMaskID);
			blue = getTitle();
			selectImage(clusterBottomMaskID);
			red = getTitle();
			selectImage(clusterTopMaskID);
			green = getTitle();
	        run("Merge Channels...", "c1=["+red+"] c2=["+green+"] c3=["+blue+"]");
			selectWindow ("RGB");
			mergedClusterID=getImageID();
			print("making montage");
			montageID = createMontage(normalGreenID, normalRedID, plotStackID, mergedClusterID, distanceMapID, ratioLogID);
			selectImage(montageID);
			saveAs("Tiff", parentDir+"Results/"+titleCut+"_"+fileNumber+"_Montage.tif");	
			close();

			selectImage(distanceMapID);
			close();

			selectImage(plotStackID);
			close();

			selectImage(ratioLogID);
			close();

			selectImage(mergedClusterID);
			close();

		}

		selectWindow("Results");
		run("Close");

		selectImage(greenID);
		close();

		selectImage(redID);
		close();

		selectImage(normalGreenID);
		close();

		selectImage(normalRedID);
		close();
	
		selectImage(maskID);
		close();

		selectImage(ratioID);
		close();
		
		close(title);

		list = getList("window.titles");
		NRexceptions =0;
		for(i=1; i<list.length; i++){
			if(list[i] == "Exception"){
				selectWindow(list[i]);	
				run("Close");
				NRexceptions++;
			}
		}
		print("Nr Exceptions was "+ NRexceptions);

	}
	
selectWindow(maxResultsTitle);
saveAs("Text",  parentDir+"/Results/MaxZonesResults.csv");
run("Close");
selectWindow(maxClusterResultsTitle);
saveAs("Text",  parentDir+"/Results/MaxClusterResults.csv");
run("Close");
exit();

	//functions used in the macro names are rather self explanatory
	//listFolders  				Lists all folders in a directory and puts them in an array
	//hasSubdir					sub routin of list files checks if folder has sub folders returns true or false
	//normalize					normalizes images (makes average of image above thresh hold and divides image by this)   
	//infinityGone				old function to remove infinity resulting from division by 0 in ratio image 
	//divideWithConstraints		divides images with constraints of a cut of if value is lower in one of the channels the pixel is set to NaN
	//onionSegment				does the segmentation of the nucleus in to onion rings
	//splitChanels				splits out the two first chanels of a hyper stack to green and red in that order 
	//createMask				creates a mask containing th largest object in the frame

  
  function listFilesAndFolders(dir, extension) {
 
  	list = getFileList(dir);
  	// the function newArray doesn't with no arguments, must really start that way
  	fileArray  = newArray(1);
  	folderArray = newArray(1);
  	print("file list length=" +list.length );
  	for (i=0; i<list.length; i++) {
  		tmp = dir + list[i]; 
  		print(tmp);

		if(endsWith(list[i], "/")) {
  		  	if (fileArray[0] == 0) {
  	   			fileArray[0] = "folder:_"+tmp;
    		} else {
        		fileArray = Array.concat("folder:_"+tmp, fileArray);
    		}
    		new_list = listFilesAndFolders(tmp, extension);
    		// if the first value is a zero, it's the first value to be entered on the
    		// array and must replace the one entered to create it
    		if (fileArray[0] == 0) {
    			fileArray  = new_list;
    		} else if (new_list.length == 1 && new_list[0] == 0) {
    			// do nothing, this directory had no good file and appending it will
    			// append a zero to the list
    		} else {
    			fileArray = Array.concat(fileArray, new_list);
    		}
		} 
		else if ( endsWith(list[i], extension ) ) {
  	    	// if the first value is a zero, it's the first value to be entered on the
  	    	// array and must replace the one entered to create it
  	    	if (fileArray[0] == 0) {
  	    		fileArray[0] = "file:_"+tmp;
  	    	} else {
  	    		fileArray = Array.concat(fileArray, ""+tmp);
  	    	}
			// if it's a directory, go recursive and get the files from there
		} 
		print("iteration = " + i);
	}
  return fileArray;
  }
  
	function splitChanels(hyperOriginal, titleCut){
		selectImage(hyperOriginal);
		var ID= newArray(2);
		if (Stack.isHyperstack == false){ 
			slices=nSlices()/2;
			run("Stack to Hyperstack...", "order=xyczt(default) channels=2 slices="+slices+" frames=1 display=Color");
			hyperOriginal = getImageID();
		}
		//get chanel1
		selectImage(hyperOriginal);
		run("Reduce Dimensionality...", "  slices keep"); //get first chanel
		rename(titleCut+"_green");
		ID[0] = getImageID();		
		run("Green");
		//get chanel2
		selectImage(hyperOriginal);
		run("Next Slice [>]");
		run("Reduce Dimensionality...", "  slices keep"); //get second chanel
		rename(titleCut+"_red");	
		ID[1] = getImageID();
		run("Red");
		return ID;
	}
	exit("error");
	
	function normalize(unNormalized, mask){ 
		showStatus("Normalizing...");
		selectImage(unNormalized);
		titleNormalized = getTitle();
		run("Duplicate...", "title="+titleNormalized+"_normalized duplicate");
		id = getImageID();
		width = getWidth(); height = getHeight();
		n = nSlices();
		run("32-bit");
		count = 0;
		sum = 0;
		//subtract background
		selectImage(mask);
		run("Duplicate...", "duplicate");
		run("Invert", "stack");
		inversMaskID = getImageID();
		roiManager("Reset");
		sumBg =0;
		for (z=1; z<=n; z++) {
			selectImage(inversMaskID);
			setSlice(z);
			getStatistics(min,max);
			if(min == 0){
				run("Create Selection");
				roiManager("Add");
				selectImage(id);
				setSlice(z);
				roiManager("Select", 0);
				roiManager("Measure");
				sumBg = sumBg + getResult("Median", nResults-1);
				roiManager("Reset");
			}
		}
		run("Select None");
		bg = sumBg/n;
		selectImage(inversMaskID);
		close();			
		selectImage(id);		
		run("Subtract...", " value="+bg+" stack");	
				
		//normalize nuclei only
		var maskArray = newArray(width*height*n);
		selectImage(mask);
		for (z=1; z<=n; z++) {
			setSlice(z);			
			for (y=0; y<height; y++) {
				for (x=0; x<width; x++) {
					pixel = getPixel(x,y);
					pos =((z-1)*width*height)+(y*width)+x;
					maskArray[pos] = pixel;
				}
			}
		}
		selectImage(id);
		for (z=1; z<=n; z++) {
			showProgress(z, n);
			setSlice(z);
			for (y=0; y<height; y++) {
				for (x=0; x<width; x++) {
					i = getPixel(x,y);
					pos =((z-1)*width*height)+(y*width)+x;
					if(maskArray[pos]>0){
						sum = sum + i;
						count++;
					}
				}
			}
		}
		avg = sum/count;
		selectImage(id);
		run("Divide...", " value="+avg+" stack");
		return id;
	}
	exit("error");
	
	function divideWithConstraints(green, red, mask, limitLevel){
		showStatus("Dividing...");
		selectImage(green);
		width = getWidth(); height = getHeight();
		n = nSlices();
		newImage("ratio", "32-bit white", width, height, n);
		ratioID = getImageID();
		run("Fire");
		pixelCount = 0;
		var maskArray = newArray(width*height*n);
		var greenArray = newArray(width*height*n);
		var redArray = newArray(width*height*n);
		var greenBgArray = newArray(width*height*n);
		var redBgArray = newArray(width*height*n);
		var averageArray = newArray(width*height*n);
		var ratioArray = newArray(width*height*n);

		setBatchMode(true);

		//pass mask to array
		for (z=1; z<=n; z++) {
			selectImage(mask);
			setSlice(z);			
			for (y=0; y<height; y++) {
				for (x=0; x<width; x++) {
					pixel = getPixel(x,y);
					pos =((z-1)*width*height)+(y*width)+x;
					maskArray[pos] = pixel;
				}
			}
		}

		//pas green to array if in mask
		selectImage(green);
		for (z=1; z<=n; z++) {
			setSlice(z);			
			for (y=0; y<height; y++) {
				for (x=0; x<width; x++) {
					pixel = getPixel(x,y);
					pos =((z-1)*width*height)+(y*width)+x;
					if (maskArray[pos] != 0){						
						greenArray[pos] = pixel;
						greenBgArray[pos] = NaN;
					}
					else{
						greenArray[pos] = NaN;
						greenBgArray[pos] = pixel;				
					}
				}
			}
		}

		//pas red to array if in mask
		selectImage(red);
		for (z=1; z<=n; z++) {
			setSlice(z);			
			for (y=0; y<height; y++) {
				for (x=0; x<width; x++) {
					pixel = getPixel(x,y);
					pos =((z-1)*width*height)+(y*width)+x;
					if (maskArray[pos] != 0){	
						redArray[pos] = pixel;
					}
					else{
						redBgArray[pos] = pixel;
					}
				}
			}
		}

		//calculate green SD and average of average nuclei
		//Average Calculation
		sumGreenArray = 0;
		count = 0;
		for (i=0; i<lengthOf(greenArray); i++){
			if(greenArray[i] > 0){
				sumGreenArray = sumGreenArray+greenArray[i];
				count++;
			}	 
		}
		averageGreenArray = sumGreenArray/count;

		//SD calculation
		sumVarianceGreenArray = 0;
		count = 0;
		for (i=0; i<lengthOf(greenArray); i++){
			if(greenArray[i] > 0){
				sumVarianceGreenArray = sumVarianceGreenArray +(greenArray[i]-averageGreenArray)*(greenArray[i]-averageGreenArray);
				count++;
			}	 
		}
		greenStdDev = sqrt(sumVarianceGreenArray/count);
		greenCutoff = averageGreenArray - (greenStdDev*limitLevel);
		print("greenCutof = "+greenCutoff);

		//calculate greenBg SD and average of average nuclei
		//calculate average
		sumGreenBgArray = 0;
		count = 0;
		for (i=0; i<lengthOf(greenBgArray); i++){
			if(greenBgArray[i] > 0){
				sumGreenBgArray = sumGreenBgArray+greenBgArray[i];
				count++;
			}	 
		}
		averageGreenBgArray = sumGreenBgArray/count;
		print("average green BG = "+ averageGreenBgArray);
		
		//calculate SD
		sumVarianceGreenBgArray = 0;
		count = 0;
		for (i=0; i<lengthOf(greenBgArray); i++){
			if(greenBgArray[i] > 0){
				sumVarianceGreenBgArray = sumVarianceGreenBgArray +(greenBgArray[i]-averageGreenBgArray)*(greenBgArray[i]-averageGreenBgArray);
				count++;
			}	 
		}
		greenBgStdDev = sqrt(sumVarianceGreenBgArray/count);
		greenBgCutoff = averageGreenBgArray + (greenBgStdDev*limitLevel);
		print("greenBgCutoff = "+greenBgCutoff);

		//calculate red SD and average of average nuclei
		sumRedArray = 0;
		count = 0;
		for (i=0; i<lengthOf(redArray); i++){
			if(redArray[i] > 0){
				sumRedArray = sumRedArray+redArray[i];
				count++;
			}	 
		}
		averageRedArray = sumRedArray/count;

		sumVarianceRedArray = 0;
		count = 0;
		for (i=0; i<lengthOf(redArray); i++){
			if(redArray[i] > 0){
				sumVarianceRedArray = sumVarianceRedArray +(redArray[i]-averageRedArray)*(redArray[i]-averageRedArray);
				count++;
			}	 
		}
		redStdDev = sqrt(sumVarianceRedArray/count);
		redCutoff = averageRedArray - (redStdDev*limitLevel);
		print("redCutoff = "+redCutoff);

		//calculate redBg SD and Avergae 
		sumRedBgArray = 0;
		count = 0;
		for (i=0; i<lengthOf(redBgArray); i++){
			if(redBgArray[i] >0){
				sumRedBgArray = sumRedBgArray+redBgArray[i];
				count++;
			}	 
		}
		averageRedBgArray = sumRedBgArray/count;

		sumVarianceRedBgArray = 0;
		count = 0;
		for (i=0; i<lengthOf(redBgArray); i++){
			if(redBgArray[i] >0){
				sumVarianceRedBgArray = sumVarianceRedBgArray +(redBgArray[i]-averageRedBgArray)*(redBgArray[i]-averageRedBgArray);
				count++;
			}	 
		}
		redBgStdDev = sqrt(sumVarianceRedBgArray/count);
		redBgCutoff = averageRedBgArray + (redBgStdDev*limitLevel);
		print("redBgCutoff = "+redBgCutoff);
		
		//calculate ratio of green over red if abbove cutoff and above averageBg + bgCutoff*SD
		for (z=1; z<=n; z++) {
			selectImage(ratioID);
			setSlice(z);			
			for (y=0; y<height; y++) {
				for (x=0; x<width; x++) {
					pos =((z-1)*width*height)+(y*width)+x;
					if(greenArray[pos]>greenBgCutoff && redArray[pos]>redBgCutoff){
						value = (greenArray[pos]/redArray[pos]);
						setPixel(x,y,value);
					}
					else{
						setPixel(x,y,NaN);
					}
				}
			}
		}

		setBatchMode(false);
		return ratioID;
	}
	exit("error");
	
	//Make Onion measurement
	function onionSegment(ratio, mask, lable, nuberofzones, doMaxRecording, percentExtraMaxRecords, activeFolder, titleCut,f, doGraph){
		setBatchMode(false);
		run("ROI Manager...");
		roiManager("reset");
		selectImage(mask);
		run("Duplicate...", "title=distanceMap duplicate");
		run("Invert", "stack");
		run("Distance Map", "stack");
		distanceMap = getImageID();
		width = getWidth();
		height = getHeight();
		s=nSlices();
		if(doMaxRecording==true){ //find cut off for max recording
			maxDistance= 1;
			for (stackSlize=1; stackSlize<=s; stackSlize++) {
				selectImage(distanceMap);
				setSlice(stackSlize);
				getStatistics(area, mean, min, max);
				if(maxDistance < max){
					maxDistance = max;		
				}
			}
			maxCutoff = floor(maxDistance-(maxDistance*percentExtraMaxRecords));
		}
		
		setBatchMode(true);
		for (stackSlize=1; stackSlize<=s; stackSlize++) {
			selectImage(distanceMap);
			setSlice(stackSlize);
			getStatistics(area, mean, min, max);		
			if (doMaxRecording==true) {
				nz=max;
			}
			else{
				nz = nuberofzones;
			}
			if(doMaxRecording==true){
				if(max>maxCutoff){
					print(f, ""+"\n"+ replace(activeFolder, "\\", "\/")+ " \t" + titleCut + " \t"+ stackSlize+ " \t" + max + " \t"); // activeFolder + "  \t"				
				}
				maxMeanResultsArray = newArray(max);
			}
			print( "MaxDistance = "+ max);
			print( "MaxCutoff = "+ maxCutoff);
			
			roiManager("Reset");
			resultsCounter = nResults();
			for(zone=2; zone<=nz; zone++) { //debug change back to 1
				selectImage(distanceMap);
				setSlice(stackSlize);
				if(max >= 1){
					setThreshold(1+((zone-1)*floor(max/nz)), zone*floor(max/nz));
					run("Create Selection");
					roiManager("Add");
					run("Select None");
					selectImage(ratio);
					setSlice(stackSlize);
					roiManager("select", roiManager("count")-1);
					roiManager("Rename", lable + "_Zone_"+zone);
					roiManager("Measure");		//Add folder structure to results some how
					if(doMaxRecording==true){
						if(nResults()>resultsCounter){
							maxMeanResultsArray[zone-1]= getResult("Mean");
							resultsCounter++;
						}
					}
					run("Select None");
				}
				else{
					print("Slize " + stackSlize + " has no info")
				}
			}
			if(doGraph == 1){
				setBatchMode(false);
				Plot.create("Slice "+ stackSlize + "", "zone", "ratio", maxMeanResultsArray);
				Plot.setLimits(0, nz, 0.5, 1.5);
				Plot.setFrameSize(width, height);
				Plot.setColor("red");
				Plot.drawNormalizedLine(0, 0.5, 1, 0.5);
				Plot.setColor("black");
				Plot.show();
				plotID = getImageID();
				run("Scale...", "x=- y=- width="+width+" height="+height+" interpolation=Bicubic  average create title=tempPlot");
				selectWindow("tempPlot");
				tempPlotID = getImageID();
				run("Select All");
				run("Copy");
				selectImage(plotStackID);
				setSlice(stackSlize);
				run("Paste");
				selectImage(tempPlotID);
				close;
				selectImage(plotID);
				close;
				setBatchMode(true);
			}
			run("Select None");			
			if(doMaxRecording==true &&  max>maxCutoff){
				for(i=0; i<lengthOf(maxMeanResultsArray); i++){
					print(f, ""+ maxMeanResultsArray[i] + " \t");
				}
				selectImage(distanceMap);
				setColor(max);
				setFont("Monospaced", 12);
				drawString(max, 2, 15);
			}
		}
		setBatchMode(false);
		run("Select None");
		return distanceMap;
	}
	exit("error");
	
	function createMask(inputImage){
		selectImage(inputImage);
		width = getWidth(); height = getHeight();
		run("Duplicate...", "title=mask duplicate");
		maskTempID = getImageID();
		selectImage(maskTempID);
		setBatchMode(true);
		run("Gaussian Blur...", "sigma=1 stack");
		run("16-bit");
		run("Auto Threshold", "method=Default white stack use_stack_histogram");
		run("Fill Holes", "stack");
		setBatchMode(false);

		run("Analyze Particles...", "size="+floor((((width+width)/8)*((height+height)/8)*PI))+"-Infinity pixel show=Masks exclude stack");
		print("size limit = " + floor((((width+width)/8)*((height+height)/8)*PI)));
		//setBatchMode(true);		

		rename("analyzed");
		
		run("Options...", "iterations=3 count=1 do=Nothing");
		run("Dilate", "stack");
		run("Erode", "stack");
		run("Fill Holes", "stack");
		run("Options...", "iterations=1 count=1 black do=Nothing");
				
		run("Gaussian Blur...", "sigma=5 stack");
		setThreshold(128, 255);
		run("Convert to Mask", "method=Default background=Default");
		//run("Invert", "stack");
		for(i=1; i<=nSlices; i++){
			setSlice(i); 
			getStatistics(area, mean, min, max);
			if(max==255){
				run("Create Selection");
				run("Convex Hull");
				run("Add...", "value=255 slice");
				run("Select None");
			}
		}
		//make convex hull to include edge nucleoli

		//run("Invert", "stack");
		maskID = getImageID();
		setBatchMode(false);
		selectImage(maskTempID);
		close();	
		return maskID;	
	}
	exit("error");
	
	function logImage(inputImage){
		selectImage(inputImage);
		run("Duplicate...", "title=logImage duplicate");
		logID = getImageID();
		selectImage(logID);
		run("Log", "stack");
		return logID;
	}
	exit("error");

	function clusterAnalysisES(mask, inputImage, cutoff, minSize, useScale){
		selectImage(inputImage);
		run("Duplicate...", "title=ClusterAnalysisES duplicate");
		clusterImage = getImageID();
		clusterTitle = getTitle();
		if(useScale == 0){
			 setVoxelSize(1,1,1, "pixel");
		}
		width = getWidth(); height = getHeight();
		n = nSlices();
		nPixels = 1;
		selectImage(mask);
		var clusterMaskArray = newArray(n*width*height);
		for (z=1; z<=n; z++) {
			setSlice(z);			
			for (y=0; y<height; y++) {
				for (x=0; x<width; x++) {				
					valPixel = getPixel(x,y);	 
					clusterMaskArray[((z-1)*width*height)+(y*width)+x]= valPixel;
					if(valPixel > 1){
						nPixels++;
					}
				}
			}
		}
		print("total pixels = "+ n*width*height);
		print("nPixels = " +nPixels);
		var clusterImageArray = newArray(nPixels);
		selectImage(clusterImage);
		pos=0;
		for (z=1; z<=n; z++) {
			setSlice(z);			
			for (y=0; y<height; y++) {
				for (x=0; x<width; x++) {
					pixel = getPixel(x,y);
					if(pixel>0 && clusterMaskArray[((z-1)*width*height)+(y*width)+x]>1 ){
						clusterImageArray[pos] = pixel;
						pos++;
					}
//					if(pos>=nPixels){
//						print("exited loop with error");
//						exit;
//					}
				}
			}
		}
		print("test1");
		Array.sort(clusterImageArray);
		limit = clusterImageArray[floor((1-cutoff)*nPixels)];
		print("Limit for ES = "+ limit + " ; and Bottom was = "+ clusterImageArray[1] + " ; and Top was = " + clusterImageArray[nPixels-1] );
		setThreshold(limit, 4); //4 is far greater than something to be concidered		
		run("NaN Background", "stack");
		run("Enhance Contrast...", "saturated=0.1 use");
		run("8-bit");
		setThreshold(1, 255);
		setOption("BlackBackground", true);
		run("Convert to Mask", "stack");
		run("Analyze Particles...", "size="+minSize+"-Infinity show=Masks display exclude clear summarize stack");
		selectWindow("Mask of "+clusterTitle);
		clusterOutlineID = getImageID();
		selectImage(clusterImage);
		close();
		selectImage(clusterOutlineID);
		var clusterArray = newArray(nSlices());
		var clusterSizeSumArray = newArray(nSlices());
		if(nResults()>2){
			for(i = 1; i < nSlices(); i++){
				for(j = 1 ; j < nResults(); j++){
					if(getResult("Slice", j) == i){
						clusterArray[i]= clusterArray[i]+1;
						clusterSizeSumArray[i] =clusterSizeSumArray[i]+ getResult("Area", j);
					}
				}
			}
		}
		else{
			print("no clusterES results");
		}
		selectImage(clusterOutlineID);
		run("Rotate 90 Degrees Right");
		setColor("black");
		setFont("Monospaced", 12);
		setJustification("center");
		for(y=1;y<nSlices();y++){
				setSlice(y);
				text = "#="+clusterArray[y]+", A="+clusterSizeSumArray[y] +"";
				drawString(text , getWidth()/2, 15);
		}
		run("Rotate 90 Degrees Left");
		
		//selectWindow(resultsZones);
		//arrayZonesResults =split (getInfo ("window.content"),"/n");
		//arrayZonesLastResult = split (arrayZonesResults[lengthOf(arrayZonesResults)], "/t");
		//maxPos=arrayZonesLastResult[3];
		//print(g, ""+"\n"+ replace(activeFolder, "\\", "\/")+ " \t" + titleCut + " \t"+ maxPos+ " \t");
		//print(g, ""+ clusterArray[maxPos] + " \t");
		//print(g, ""+ clusterSizeSumArray[maxPos] + " \t");
		return clusterOutlineID;
	}
	
	function clusterAnalysisRF(inputImage, direction, cutoff, minSize){
		selectImage(inputImage);
		if(direction == 0){
			clusterAnalysisTitle = "ClusterAnalysisBottom";
		}
		else{
			clusterAnalysisTitle = "ClusterAnalysisTop";			
		}
		run("Duplicate...", "title=["+ clusterAnalysisTitle+ "] duplicate");
		clusterImage = getImageID();
		clusterTitle = getTitle();
		width = getWidth(); height = getHeight();
		n = nSlices();
		nPixels = 0;
		for (z=1; z<=n; z++) {
			setSlice(z);			
			for (y=0; y<height; y++) {
				for (x=0; x<width; x++) {					 
					if(getPixel(x,y) > -2){ //set this to a nicer value ie SD * X
						nPixels = nPixels + 1;
					}
				}
			}
		}
		print("total pixels = "+ n*width*height);
		print("nPixels = " +nPixels);
		var clusterImageArray = newArray(nPixels);
		selectImage(clusterImage);
		pos=0;
		for (z=1; z<=n; z++) {
			setSlice(z);			
			for (y=0; y<height; y++) {
				for (x=0; x<width; x++) {
					pixel = getPixel(x,y);
					if(pixel >-2){
						clusterImageArray[pos] = pixel;
						pos++;
					}
				}
			}
		}
		Array.sort(clusterImageArray);
		if(direction == 0){
			limit = clusterImageArray[floor(cutoff*nPixels)];
			print("position =" + cutoff*nPixels +" limit =" +limit);
			setThreshold(-2, limit);
		}
		else{
			limit = clusterImageArray[floor((1-cutoff)*nPixels)];
			setThreshold(limit, 2);			
		}
		run("NaN Background", "stack");
		run("Enhance Contrast...", "saturated=0.1 use");
		run("8-bit");
		setThreshold(1, 255);
		setOption("BlackBackground", true);
		run("Convert to Mask", "stack");
		run("Analyze Particles...", "size="+minSize+"-Infinity show=Masks display exclude clear summarize stack");
		selectWindow("Mask of "+clusterTitle);
		clusterOutlineID = getImageID();
		selectImage(clusterImage);
		close();
		selectImage(clusterOutlineID);
		var clusterArray = newArray(nSlices());
		var clusterSizeSumArray = newArray(nSlices());
		for(i = 1; i < nSlices(); i++){
			for(j = 1 ; j < nResults(); j++){
				if(getResult("Slice", j) == i){
					clusterArray[i]= clusterArray[i]+1;
					clusterSizeSumArray[i] =clusterSizeSumArray[i]+ getResult("Area", j);
				}
				else{
					
				}
			}
		}
		selectImage(clusterOutlineID);
		if(direction == 0){
			xPos = width/2;
			yPos = height-1;
		}
		else{
			xPos = width/2;
			yPos = 15;	
		}		
		setJustification("center");
		setColor("black");
		setFont("Monospaced", 12);
		for(y=1;y<nSlices();y++){
				setSlice(y);
				text = "#="+clusterArray[y]+", A="+clusterSizeSumArray[y] +"";
				drawString(text , xPos, yPos);
		}
		maxPos = 0;
		max = 0;
		for(w=0; w<lengthOf(clusterArray);w++){
			if(clusterArray[w] > max){
				maxPos = w;
				max = clusterArray[w];
			}
		}
		print(g, ""+"\n"+ replace(activeFolder, "\\", "\/")+ " \t" + titleCut + " \t"+ maxPos+ " \t");
		print(g, ""+ clusterArray[maxPos] + " \t");
		print(g, ""+ clusterSizeSumArray[maxPos] + " \t");
		return clusterOutlineID;
	}

	function createMontage(green, red, mask, ratio, onion, ratioLog){
		setBatchMode(true);
		tempGreen = createBorder(green, "greenForMontage");
		tempRed = createBorder(red, "redForMontage");
		run("Combine...", "stack1="+ tempGreen +" stack2="+ tempRed +"");
		rename("tempConcat1");


		tempRatio = createBorder(ratio, "tempRatioForMontage");
		tempRatioLog = createBorder(ratioLog, "tempRatioLogForMontage");
		run("Combine...", "stack1="+tempRatio+" stack2="+ tempRatioLog +"");
		rename("tempConcat2");
		
		run("Combine...", "stack1=tempConcat1 stack2=tempConcat2 combine");
		rename("tempConcat3");
		
		tempMask = createBorder(mask, "tempMaskForMontage");
		tempOnion = createBorder(onion, "tempOnionForMontage");
		run("Combine...", "stack1="+tempMask+" stack2="+ tempOnion +"");
		rename("tempConcat4");
		
		run("Combine...", "stack1=tempConcat3 stack2=tempConcat4 combine");
		montageID = getImageID();

		setBatchMode(false);
		
		return montageID;
	}

	function createBorder(inputImage,tempTitle){
		selectImage(inputImage);
		width = getWidth(); height = getHeight();
		title = getTitle();
		run("Duplicate...","title="+tempTitle+" duplicate");
		temp = getImageID();
		setBatchMode(true);
		selectImage(temp);
		run("Enhance Contrast", "saturated=0.01 use");
		run("RGB Color");
		setBackgroundColor(255,255,255);
		run("Canvas Size...", "width=" + width+2 + " height=" + height+2 + " position=Center");
		setBatchMode(false);
		selectImage(temp);
		return getTitle();
	}
	exit("error");

	
