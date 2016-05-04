arguments = getArgument(); // get the inital argument string
argumentArray = split(arguments,  "|");// split the string in to fragments

normalize(argumentArray[0], argumentArray[1])

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