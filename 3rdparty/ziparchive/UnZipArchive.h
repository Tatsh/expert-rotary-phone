//
//  ZipArchive.h
//  
//
//  Created by aish on 08-9-11.
//  acsolu@gmail.com
//  Copyright 2008  Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#include "minizip/zip.h"
#include "minizip/unzip.h"


@protocol ZipArchiveDelegate <NSObject>
@optional
-(void) ErrorMessage:(NSString*) msg;
-(BOOL) OverWriteOperation:(NSString*) file;

@end


// Vendored ZipArchive (Google Code "ziparchive" snapshot, ~2014) renamed to UnZipArchive and
// extended with the extract-to-NSData API the reconstruction calls, alongside the original
// CreateZipFile2 / UnzipOpenFile: / UnzipFileTo: methods. Backed by ./minizip.
@interface UnZipArchive : NSObject {
@private
	zipFile		_zipFile;
	unzFile		_unzFile;

	NSString*   _password;
	id			_delegate;
}

@property (nonatomic, retain) id delegate;

-(BOOL) CreateZipFile2:(NSString*) zipFile;
-(BOOL) CreateZipFile2:(NSString*) zipFile Password:(NSString*) password;
-(BOOL) addFileToZip:(NSString*) file newname:(NSString*) newname;
-(BOOL) CloseZipFile2;

-(BOOL) UnzipOpenFile:(NSString*) zipFile;
-(BOOL) UnzipOpenFile:(NSString*) zipFile Password:(NSString*) password;
-(BOOL) UnzipFileTo:(NSString*) path overWrite:(BOOL) overwrite;
-(BOOL) UnzipCloseFile;

// --- API the reconstruction (MusicData.m / AcMusicData.m) calls -----------------------------
// Open `path` for reading; extract one entry straight to NSData; close.
-(BOOL) openFile:(NSString*) path;
-(NSData*) getData:(NSString*) entryName;
-(void) closeFile;
@end
