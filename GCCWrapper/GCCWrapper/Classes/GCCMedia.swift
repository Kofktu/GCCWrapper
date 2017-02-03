//
//  GCCMedia.swift
//  GCCWrapper
//
//  Created by kofktu on 2017. 2. 3..
//  Copyright © 2017년 Kofktu. All rights reserved.
//

import UIKit
import GoogleCast

public protocol GCCMediaInformation {
    var contentUrl: String! { get }
    var contentType: String { get }
}

public extension GCCMediaInformation where Self: GCCMedia {
    public var metadata: GCKMediaMetadata? {
        let metadata = GCKMediaMetadata(metadataType: .generic)
        var isEmpty = true
        
        if let title = title {
            isEmpty = false
            metadata.setString(title, forKey: kGCKMetadataKeyTitle)
        }
        if let subtitle = subtitle {
            isEmpty = false
            metadata.setString(subtitle, forKey: kGCKMetadataKeySubtitle)
        }
        if let imageUrl = imageUrl, let url = URL(string: imageUrl) {
            isEmpty = false
            let size = imageSize ?? CGSize(width: 200.0, height: 200.0)
            metadata.addImage(GCKImage(url: url, width: Int(size.width), height: Int(size.height)))
        }
        return isEmpty ? nil : metadata
    }
    
    public var mediaInformation: GCKMediaInformation? {
        guard let contentUrl = contentUrl else { return nil }
        return GCKMediaInformation(contentID: contentUrl,
                                   streamType: .none,
                                   contentType: contentType,
                                   metadata: metadata,
                                   streamDuration: 0,
                                   customData: nil)
    }
}

open class GCCMedia: GCCMediaInformation {
    open var contentType: String {
        fatalError("Subclass implement")
    }
    
    open var contentUrl: String!
    open var title: String?
    open var subtitle: String?
    open var imageUrl: String?
    open var imageSize: CGSize? // defaultSize is {200, 200}
    
    
    public init(contentUrl: String, title: String?, subtitle: String?, imageUrl: String?, imageSize: CGSize?) {
        self.contentUrl = contentUrl
        self.title = title
        self.subtitle = subtitle
        self.imageUrl = imageUrl
        self.imageSize = imageSize
    }
}

open class GCCMediaAudio: GCCMedia {
    open override var contentType: String {
        return "audio/mpeg"
    }
}
