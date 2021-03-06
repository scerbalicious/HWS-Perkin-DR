# functions used in Filter_Imgae_Processing_Script.R
# Author Drew Scerbo
# October 22, 2017

# function to compare two date directories
# return > 0 if dir1 came first
# return < 0 if dir2 came first
# return 0 otherwise
compare_dates <- function(dir1, dir2) {
  d1 <- as.Date(dir1, "%Y%m%d")
  d2 <- as.Date(dir2, "%Y%m%d")
  return(as.numeric(d1 - d2))
}

# sorts 'basenames' directories by difference
# in time to the original directory
sort_files <- function(basenames, original) {
  differences <- c()
  files2 <- c()
  for (f in basenames) {
    comp <- compare_dates(f, original)
    if (!is.na(comp)) {
      differences <- c(differences, abs(as.numeric(comp)))
      files2 <- c(files2, f)
    }
  }
  df <- data.frame(file = files2, differnce = differences)
  df <- df[order(differences),]
  return(df)
}

# given a type of image to find and a directory to look
# in, will return list of all files of that type
# will sort by filter if type is 'Flat Field'
get_files_of_type <- function(p.dir, type, filters) {
  print(paste('looking for', type, 'in:', p.dir))
  if (type == 'Flat Field')
    print(paste('Filters needed:', filters))
  if (!file.exists(p.dir)) {
    print(paste(p.dir, "doesn't exists"))
    return(list())
  }
  new_files <-
    list.files(
      path = p.dir,
      pattern = "*.fits",
      full.names = T,
      recursive = TRUE
    )
  counter <- 0
  modCounter <- 0
  fileCounter <- 0
  count <- length(new_files)
  fileList <- list()
  print(paste('Looking in', count, 'more files'))
  
  if (type == 'Flat Field') {
    gFiles <- list()
    iFiles <- list()
    rFiles <- list()
    yFiles <- list()
    zFiles <- list()
    flatFieldFilters <-
      list(gFiles, iFiles, rFiles, yFiles, zFiles)
    flatCounter <- c(0,0,0,0,0)
  }
  
  for (x in new_files) {
    
    if (grepl('mod_', basename(x))) next
    if (grepl('calibration masters', x)) next
    
    zz <- file(description = x, open = "rb")
    header <- readFITSheader(zz)
    hdr <- parseHdr(header)
    s <- hdr[which(hdr == "IMAGETYP") + 1]
    filter <- hdr[which(hdr == "FILTER") + 1]
    
    # sort by filter if flat field
    if (s == type && type == 'Flat Field') {
      if (filter %in% filters) {
        flatCounter[[get_filter_index(filter)]] <-
          flatCounter[[get_filter_index(filter)]] + 1
        counter <- counter + 1
        print(paste('Found', counter, 'new flat files of filter', filter))
        if (filter == "g''" || filter == "gp") {
          gFiles[[length(gFiles) + 1]] <- x
        } else if (filter == "i''" || filter == "ip") {
          iFiles[[length(iFiles) + 1]] <- x
        } else if (filter == "r''" || filter == "rp") {
          rFiles[[length(rFiles) + 1]] <- x
        } else if (filter == "Y''" || filter == "Yp") {
          yFiles[[length(yFiles) + 1]] <- x
        } else if (filter == "z''" || filter == "zp") {
          zFiles[[length(zFiles) + 1]] <- x
        } else {
          print("NO FILTER: file should have a filter")
          stopifnot(FALSE)
        }
      }
    } else if (s == type) {
      counter <- counter + 1
      print(paste('Found', counter, 'new files of type', s))
      fileList[[length(fileList) + 1]] <- x
    }
    close(zz)
  }
  
  if (type == 'Flat Field') {
    return(list(gFiles, iFiles, rFiles, yFiles, zFiles))
  } else{
    print(paste('Found in total', length(fileList), 'more', type, 'files'))
    return(fileList)
  }
}

# Look for dark files of given types in the given directory
get_dark_files <- function(p.dir, expTimes) {
  print(paste('looking for darks in:', p.dir))
  if (!file.exists(p.dir)) {
    print(paste(p.dir, "doesn't exists"))
    return(list())
  }
  new_files <-
    list.files(
      path = p.dir,
      pattern = "*.fits",
      full.names = T,
      recursive = TRUE
    )
  counter <- 0
  fileList <- list()
  count <- length(new_files)
  print(paste('Looking at', count, 'more files'))
  
  for (x in new_files) {
    
    if (grepl('mod_', basename(x))) next
    if (grepl('calibration masters', x)) next
    
    zz <- file(description = x, open = "rb")
    header <- readFITSheader(zz)
    
    close(zz)
    hdr <- parseHdr(header)
    s <- hdr[which(hdr == "IMAGETYP") + 1]
    exp <- hdr[which(hdr == "EXPTIME") + 1]
    
    difference <- .Machine$integer.max
    for (e in expTimes){
      difference <- abs(as.numeric(exp) - as.numeric(e))
    }
    if (s == 'Dark Frame' && difference <= .5*as.numeric(exp)) {
      fileList[[length(fileList) + 1]] <- x
      counter <- counter + 1
      print(paste('Found', counter, 'new dark fames of exposure time', exp))
    }
  }
  print(paste('Found in total', counter, 'more Dark Frame files'))
  return(fileList)
}


# get the associated index given a specific filter
# this order of filters is used everywhere
get_filter_index <- function(filter) {
  if (filter == "g''" || filter == "gp")
    return(1)
  if (filter == "i''" || filter == "ip")
    return(2)
  if (filter == "r''" || filter == "rp")
    return(3)
  if (filter == "Y''" || filter == "Yp")
    return(4)
  if (filter == "z''" || filter == "zp")
    return(5)
  return(-1)
}


# function to average dark frames into a master dark frame
darkCounter <- function(files) {
  masterDark <-
    array(0, dim = c(xNumber, yNumber))
  for (count in 1:length(files)) {
    counter <- counter + 1
    Y <- readFITS(x)
    masterDark <- masterDark + Y$imDat - masterBias
  }
  masterDark <- masterDark / counter
  return(masterDark)
}


# Average the value of each flat field and sort by filters
flatFunction <- function(f,filter) {
  # Get average count of all pixels in an image
  masterFlat <- array(0, dim = c(xNumber, yNumber))
  flatCounter <- 0
  print(paste("Averaging master",filter,"flat of",length(f),"files"))
  for (file in f) {
    Y <- readFITS(file)
    img <- Y$imDat
    
    # normalize the image
    avg <- mean(img - masterBias)
    masterFlat <- masterFlat + ((img - masterBias) / avg)
    flatCounter <- flatCounter + 1
  }
  
  if (is.nan(masterFlat[xNumber / 2, yNumber / 2]))
    return(NULL)
  else
    return(masterFlat / flatCounter)
}

# Writes the calibrated science frame in the given directory
writeCalScience <- function (science, x, Y,darkUsed) {
  fName <- paste("mod_", basename(x), sep = '')
  bzero <- Y$hdr[which(Y$hdr == "BZERO") + 1]
  bscale <- Y$hdr[which(Y$hdr == "BSCALE") + 1]
  f <- file.path(script.dir, 'modified images', fName)
  header <- Y$header
  header <- addKwv("BSUBDIR",biasDirectory,"Directory bias frames are from",header=header)
  if (darkUsed > 0) {
    header <- addKwv("DSUBDIR",exposureTimes[[darkUsed]],darkDirectory[[darkUsed]],header=header)
  } else {
    header <- addKwv("DSUBDIR","NONE",header=header)
  }
  filter <- get_filter_index(Y$hdr[which(Y$hdr == "FILTER") + 1])
  if (filter == 1){
    if (exists("masterGFlat")) {
      dir <- basename(gFlatDirectory)
      header <- addKwv("FLATDIR","g''",dir,header=header)
    } else header <- addKwv("FLATDIR","g''","NONE",header=header)
  }
  if (filter == 2){
    if (exists("masterIFlat")) {
      dir <- basename(iFlatDirectory)
      header <- addKwv("FLATDIR","i''",dir,header=header)
    } else header <- addKwv("FLATDIR","i''","NONE",header=header)
  }
  if (filter == 3){
    if (exists("masterRFlat")) {
      dir <- basename(rFlatDirectory)
      header <- addKwv("FLATDIR","r''",dir,header=header)
    } else header <- addKwv("FLATDIR","r''","NONE",header=header)
  }
  if (filter == 4){
    if (exists("masterYFlat")) {
      dir <- basename(yFlatDirectory)
      header <- addKwv("FLATDIR","Y''",dir,header=header)
    } else header <- addKwv("FLATDIR","Y''","NONE",header=header)
  }
  if (filter == 5){
    if (exists("masterZFlat")) {
      dir <- basename(zFlatDirectory)
      header <- addKwv("FLATDIR","z''",dir,header=header)
    } else header <- addKwv("FLATDIR","z''","NONE",header=header)
  }
  
  writeFITSim(
    calScience,
    file = f,
    axDat = Y$axDat,
    header = header,
    bscale = strtoi(bscale)
  )
  return(fName)
}
