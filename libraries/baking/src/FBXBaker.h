//
//  FBXBaker.h
//  tools/baking/src
//
//  Created by Stephen Birarda on 3/30/17.
//  Copyright 2017 High Fidelity, Inc.
//
//  Distributed under the Apache License, Version 2.0.
//  See the accompanying file LICENSE or http://www.apache.org/licenses/LICENSE-2.0.html
//

#ifndef hifi_FBXBaker_h
#define hifi_FBXBaker_h

#include <QtCore/QFutureSynchronizer>
#include <QtCore/QDir>
#include <QtCore/QUrl>
#include <QtNetwork/QNetworkReply>

#include "Baker.h"
#include "TextureBaker.h"
#include "ModelBaker.h"
#include "ModelBakingLoggingCategory.h"

#include <gpu/Texture.h> 

#include <FBX.h>

using TextureBakerThreadGetter = std::function<QThread*()>;

class FBXBaker : public ModelBaker {
    Q_OBJECT
public:
    FBXBaker(const QUrl& inputModelURL, TextureBakerThreadGetter inputTextureThreadGetter,
        const QString& bakedOutputDirectory, const QString& originalOutputDirectory = "", bool hasBeenBaked = false);

protected:
    virtual void bakeProcessedSource(const hfm::Model::Pointer& hfmModel, const std::vector<hifi::ByteArray>& dracoMeshes, const std::vector<std::vector<hifi::ByteArray>>& dracoMaterialLists) override;

private:
    void rewriteAndBakeSceneModels(const QVector<hfm::Mesh>& meshes, const std::vector<hifi::ByteArray>& dracoMeshes, const std::vector<std::vector<hifi::ByteArray>>& dracoMaterialLists);
    void rewriteAndBakeSceneTextures();
    void replaceMeshNodeWithDraco(FBXNode& meshNode, const QByteArray& dracoMeshBytes, const std::vector<hifi::ByteArray>& dracoMaterialList);

    hfm::Model::Pointer _hfmModel;
    QHash<QString, int> _textureNameMatchCount;
    QHash<QUrl, QString> _remappedTexturePaths;

    bool _pendingErrorEmission { false };
};

#endif // hifi_FBXBaker_h
