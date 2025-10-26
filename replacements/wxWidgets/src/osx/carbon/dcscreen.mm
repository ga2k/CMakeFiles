/////////////////////////////////////////////////////////////////////////////
// Modified:    Geoffrey Hoffmann and ChatGTP
// Name:        src/osx/carbon/dcscreen.mm
// Purpose:     wxScreenDC class
// Author:      Stefan Csomor
// Created:     1998-01-01
// Copyright:   (c) Stefan Csomor
// Licence:     wxWindows licence
/////////////////////////////////////////////////////////////////////////////

#include "wx/wxprec.h"
#include "wx/dcscreen.h"
#include "wx/osx/dcscreen.h"

#include "wx/osx/private.h"
#include "wx/graphics.h"

#import <ScreenCaptureKit/ScreenCaptureKit.h>

wxIMPLEMENT_ABSTRACT_CLASS(wxScreenDCImpl, wxWindowDCImpl);

// Create a DC representing the whole screen
wxScreenDCImpl::wxScreenDCImpl(wxDC* owner) :
    wxWindowDCImpl(owner)
{
#if !wxOSX_USE_IPHONE
    CGRect cgbounds;
    cgbounds = CGDisplayBounds(CGMainDisplayID());
    m_width = (wxCoord)cgbounds.size.width;
    m_height = (wxCoord)cgbounds.size.height;
    SetGraphicsContext(wxGraphicsContext::Create());
    m_ok = true;
#endif
    m_contentScaleFactor = wxOSXGetMainScreenContentScaleFactor();
}

wxScreenDCImpl::~wxScreenDCImpl()
{
    wxDELETE(m_graphicContext);
}

wxBitmap wxScreenDCImpl::DoGetAsBitmap(const wxRect* subrect) const
{
    wxRect rect = subrect ? *subrect : wxRect(0, 0, m_width, m_height);

    wxBitmap bmp(rect.GetSize(), 32);

#if !wxOSX_USE_IPHONE

    CGRect srcRect = CGRectMake(rect.x, rect.y, rect.width, rect.height);

    CGContextRef context = (CGContextRef)bmp.GetHBITMAP();

    CGContextSaveGState(context);

    CGContextTranslateCTM(context, 0, m_height);
    CGContextScaleCTM(context, 1, -1);

    if (subrect)
        srcRect = CGRectOffset(srcRect, -subrect->x, -subrect->y);

    CGImageRef image = nullptr;

#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 150000
    if (@available(macOS 15.0, *))
    {
        // ScreenCaptureKit implementation
        __block CGImageRef capturedImage = nullptr;
        NSError* error = nil;

        SCShareableContent* content = [SCShareableContent shareableContentWithCompletionHandler:^(SCShareableContent* _Nullable content, NSError* _Nullable error) {
            if (error) {
                NSLog(@"Failed to fetch shareable content: %@", error);
                return;
            }

            SCDisplay* display = content.displays.firstObject;
            if (!display) {
                NSLog(@"No displays found");
                return;
            }

            [display requestCaptureWithOptions:SCFrameRequestOptionsNone completionHandler:^(SCFrameResult* _Nullable frame, NSError* _Nullable error) {
                if (error) {
                    NSLog(@"Failed to capture screen frame: %@", error);
                    return;
                }
                capturedImage = CGImageRetain(frame.cgImage);
            }];
        }];

        // Simple run loop to wait for asynchronous capture
        while (!capturedImage) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }

        image = capturedImage;
    }
#else

    if (!image)
    {
        // Fallback for macOS < 15
        image = CGDisplayCreateImage(kCGDirectMainDisplay);
    }

    wxASSERT_MSG(image, wxT("wxScreenDC::GetAsBitmap - unable to get screenshot."));

    CGContextDrawImage(context, srcRect, image);

    if (image)
    {
        CGImageRelease(image);
    }

    CGContextRestoreGState(context);
#endif
#endif
    return bmp;
}
