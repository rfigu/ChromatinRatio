bestGeneratedFilePath = "c:\someNiceFOldertostoreCrap\nicestuff.csv";


// Create function that takes a originalImageFolderName (or folderPath) as input and returns an array of images (or imagefiles or filenames).
// In this loop, create 2 text files to hold results, OnionResult, ClusterResults (created in subMacros).

runMacro("CreateMask", "OriginalImageName|MaskImageName");
runMacro("NormalizeImages", "MaskImageName|OriginalImageName|NormalizedRedImageName|NormalizedGreenImageName"); //run for each of green and red images, output is two files (in the end)
//if images are fucked up, dont run more macros in these images, move on to the next.
runMacro("CreateRatioImage", "NormalizedRedImageName|NormalizedGreenImageName|RatioImage"); 
runMacro("CreateOnionSegment", "RatioImage|MaskImageName|originalImageFolderName|bestGeneratedFilePath"); //partial result 
runMacro("CreateClusterImage", "MaskImageName|NormalizedRedImageName|NormalizedRedImageName|RatioImage|6 other nice variables from user prompt"); 

//more functions to display results to user
