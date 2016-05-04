arguments = getArgument(); // get the inital argument string
argumentArray = split(arguments,  "|");// split the string in to fragments

splitCanels(argumentArray[0], argumentArray[1])


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
