//
//  AssetServer.h
//
//  Created by Ryan Huffman on 2015/07/21
//  Copyright 2015 High Fidelity, Inc.
//
//  Distributed under the Apache License, Version 2.0.
//  See the accompanying file LICENSE or http://www.apache.org/licenses/LICENSE-2.0.html
//

#ifndef hifi_AssetServer_h
#define hifi_AssetServer_h

#include <QDir>

#include <ThreadedAssignment.h>

#include "AssetUtils.h"

class AssetServer : public ThreadedAssignment {
    Q_OBJECT
public:
    AssetServer(NLPacket& packet);
    ~AssetServer();

    static QString hashData(const QByteArray& data);

public slots:
    void run();

private slots:
    void handleAssetGetInfo(QSharedPointer<NLPacket> packet, SharedNodePointer senderNode);
    void handleAssetGet(QSharedPointer<NLPacket> packet, SharedNodePointer senderNode);
    void handleAssetUpload(QSharedPointer<NLPacket> packet, SharedNodePointer senderNode);

private:
    static void writeError(NLPacket* packet, AssetServerError error);
    QDir _resourcesDirectory;
};

#endif
