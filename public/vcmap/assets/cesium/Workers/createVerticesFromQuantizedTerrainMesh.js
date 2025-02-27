define(['./AxisAlignedBoundingBox-ff186ccc', './Matrix2-13178034', './Matrix3-315394f6', './defaultValue-0a909f67', './TerrainEncoding-833187da', './IndexDatatype-a55ceaa1', './Math-2dbd6b93', './Check-666ab1a0', './Transforms-40229881', './WebMercatorProjection-13a90d41', './createTaskProcessorWorker', './RuntimeError-06c93819', './AttributeCompression-b646d393', './ComponentDatatype-f7b11d02', './WebGLConstants-a8cc3e8c', './combine-ca22a614'], function (AxisAlignedBoundingBox, Matrix2, Matrix3, defaultValue, TerrainEncoding, IndexDatatype, Math$1, Check, Transforms, WebMercatorProjection, createTaskProcessorWorker, RuntimeError, AttributeCompression, ComponentDatatype, WebGLConstants, combine) {
  'use strict';

  /**
   * Provides terrain or other geometry for the surface of an ellipsoid.  The surface geometry is
   * organized into a pyramid of tiles according to a {@link TilingScheme}.  This type describes an
   * interface and is not intended to be instantiated directly.
   *
   * @alias TerrainProvider
   * @constructor
   *
   * @see EllipsoidTerrainProvider
   * @see CesiumTerrainProvider
   * @see VRTheWorldTerrainProvider
   * @see GoogleEarthEnterpriseTerrainProvider
   */
  function TerrainProvider() {
    Check.DeveloperError.throwInstantiationError();
  }
  Object.defineProperties(TerrainProvider.prototype, {
    /**
     * Gets an event that is raised when the terrain provider encounters an asynchronous error..  By subscribing
     * to the event, you will be notified of the error and can potentially recover from it.  Event listeners
     * are passed an instance of {@link TileProviderError}.
     * @memberof TerrainProvider.prototype
     * @type {Event<TerrainProvider.ErrorEvent>}
     * @readonly
     */
    errorEvent: {
      get: Check.DeveloperError.throwInstantiationError
    },
    /**
     * Gets the credit to display when this terrain provider is active.  Typically this is used to credit
     * the source of the terrain. This function should
     * not be called before {@link TerrainProvider#ready} returns true.
     * @memberof TerrainProvider.prototype
     * @type {Credit}
     * @readonly
     */
    credit: {
      get: Check.DeveloperError.throwInstantiationError
    },
    /**
     * Gets the tiling scheme used by the provider.  This function should
     * not be called before {@link TerrainProvider#ready} returns true.
     * @memberof TerrainProvider.prototype
     * @type {TilingScheme}
     * @readonly
     */
    tilingScheme: {
      get: Check.DeveloperError.throwInstantiationError
    },
    /**
     * Gets a value indicating whether or not the provider is ready for use.
     * @memberof TerrainProvider.prototype
     * @type {Boolean}
     * @readonly
     */
    ready: {
      get: Check.DeveloperError.throwInstantiationError
    },
    /**
     * Gets a promise that resolves to true when the provider is ready for use.
     * @memberof TerrainProvider.prototype
     * @type {Promise.<Boolean>}
     * @readonly
     */
    readyPromise: {
      get: Check.DeveloperError.throwInstantiationError
    },
    /**
     * Gets a value indicating whether or not the provider includes a water mask.  The water mask
     * indicates which areas of the globe are water rather than land, so they can be rendered
     * as a reflective surface with animated waves.  This function should not be
     * called before {@link TerrainProvider#ready} returns true.
     * @memberof TerrainProvider.prototype
     * @type {Boolean}
     * @readonly
     */
    hasWaterMask: {
      get: Check.DeveloperError.throwInstantiationError
    },
    /**
     * Gets a value indicating whether or not the requested tiles include vertex normals.
     * This function should not be called before {@link TerrainProvider#ready} returns true.
     * @memberof TerrainProvider.prototype
     * @type {Boolean}
     * @readonly
     */
    hasVertexNormals: {
      get: Check.DeveloperError.throwInstantiationError
    },
    /**
     * Gets an object that can be used to determine availability of terrain from this provider, such as
     * at points and in rectangles.  This function should not be called before
     * {@link TerrainProvider#ready} returns true.  This property may be undefined if availability
     * information is not available.
     * @memberof TerrainProvider.prototype
     * @type {TileAvailability}
     * @readonly
     */
    availability: {
      get: Check.DeveloperError.throwInstantiationError
    }
  });
  var regularGridIndicesCache = [];

  /**
   * Gets a list of indices for a triangle mesh representing a regular grid.  Calling
   * this function multiple times with the same grid width and height returns the
   * same list of indices.  The total number of vertices must be less than or equal
   * to 65536.
   *
   * @param {Number} width The number of vertices in the regular grid in the horizontal direction.
   * @param {Number} height The number of vertices in the regular grid in the vertical direction.
   * @returns {Uint16Array|Uint32Array} The list of indices. Uint16Array gets returned for 64KB or less and Uint32Array for 4GB or less.
   */
  TerrainProvider.getRegularGridIndices = function (width, height) {
    //>>includeStart('debug', pragmas.debug);
    if (width * height >= Math$1.CesiumMath.FOUR_GIGABYTES) {
      throw new Check.DeveloperError("The total number of vertices (width * height) must be less than 4,294,967,296.");
    }
    //>>includeEnd('debug');

    var byWidth = regularGridIndicesCache[width];
    if (!defaultValue.defined(byWidth)) {
      regularGridIndicesCache[width] = byWidth = [];
    }
    var indices = byWidth[height];
    if (!defaultValue.defined(indices)) {
      if (width * height < Math$1.CesiumMath.SIXTY_FOUR_KILOBYTES) {
        indices = byWidth[height] = new Uint16Array((width - 1) * (height - 1) * 6);
      } else {
        indices = byWidth[height] = new Uint32Array((width - 1) * (height - 1) * 6);
      }
      addRegularGridIndices(width, height, indices, 0);
    }
    return indices;
  };
  var regularGridAndEdgeIndicesCache = [];

  /**
   * @private
   */
  TerrainProvider.getRegularGridIndicesAndEdgeIndices = function (width, height) {
    //>>includeStart('debug', pragmas.debug);
    if (width * height >= Math$1.CesiumMath.FOUR_GIGABYTES) {
      throw new Check.DeveloperError("The total number of vertices (width * height) must be less than 4,294,967,296.");
    }
    //>>includeEnd('debug');

    var byWidth = regularGridAndEdgeIndicesCache[width];
    if (!defaultValue.defined(byWidth)) {
      regularGridAndEdgeIndicesCache[width] = byWidth = [];
    }
    var indicesAndEdges = byWidth[height];
    if (!defaultValue.defined(indicesAndEdges)) {
      var indices = TerrainProvider.getRegularGridIndices(width, height);
      var edgeIndices = getEdgeIndices(width, height);
      var westIndicesSouthToNorth = edgeIndices.westIndicesSouthToNorth;
      var southIndicesEastToWest = edgeIndices.southIndicesEastToWest;
      var eastIndicesNorthToSouth = edgeIndices.eastIndicesNorthToSouth;
      var northIndicesWestToEast = edgeIndices.northIndicesWestToEast;
      indicesAndEdges = byWidth[height] = {
        indices: indices,
        westIndicesSouthToNorth: westIndicesSouthToNorth,
        southIndicesEastToWest: southIndicesEastToWest,
        eastIndicesNorthToSouth: eastIndicesNorthToSouth,
        northIndicesWestToEast: northIndicesWestToEast
      };
    }
    return indicesAndEdges;
  };
  var regularGridAndSkirtAndEdgeIndicesCache = [];

  /**
   * @private
   */
  TerrainProvider.getRegularGridAndSkirtIndicesAndEdgeIndices = function (width, height) {
    //>>includeStart('debug', pragmas.debug);
    if (width * height >= Math$1.CesiumMath.FOUR_GIGABYTES) {
      throw new Check.DeveloperError("The total number of vertices (width * height) must be less than 4,294,967,296.");
    }
    //>>includeEnd('debug');

    var byWidth = regularGridAndSkirtAndEdgeIndicesCache[width];
    if (!defaultValue.defined(byWidth)) {
      regularGridAndSkirtAndEdgeIndicesCache[width] = byWidth = [];
    }
    var indicesAndEdges = byWidth[height];
    if (!defaultValue.defined(indicesAndEdges)) {
      var gridVertexCount = width * height;
      var gridIndexCount = (width - 1) * (height - 1) * 6;
      var edgeVertexCount = width * 2 + height * 2;
      var edgeIndexCount = Math.max(0, edgeVertexCount - 4) * 6;
      var vertexCount = gridVertexCount + edgeVertexCount;
      var indexCount = gridIndexCount + edgeIndexCount;
      var edgeIndices = getEdgeIndices(width, height);
      var westIndicesSouthToNorth = edgeIndices.westIndicesSouthToNorth;
      var southIndicesEastToWest = edgeIndices.southIndicesEastToWest;
      var eastIndicesNorthToSouth = edgeIndices.eastIndicesNorthToSouth;
      var northIndicesWestToEast = edgeIndices.northIndicesWestToEast;
      var indices = IndexDatatype.IndexDatatype.createTypedArray(vertexCount, indexCount);
      addRegularGridIndices(width, height, indices, 0);
      TerrainProvider.addSkirtIndices(westIndicesSouthToNorth, southIndicesEastToWest, eastIndicesNorthToSouth, northIndicesWestToEast, gridVertexCount, indices, gridIndexCount);
      indicesAndEdges = byWidth[height] = {
        indices: indices,
        westIndicesSouthToNorth: westIndicesSouthToNorth,
        southIndicesEastToWest: southIndicesEastToWest,
        eastIndicesNorthToSouth: eastIndicesNorthToSouth,
        northIndicesWestToEast: northIndicesWestToEast,
        indexCountWithoutSkirts: gridIndexCount
      };
    }
    return indicesAndEdges;
  };

  /**
   * @private
   */
  TerrainProvider.addSkirtIndices = function (westIndicesSouthToNorth, southIndicesEastToWest, eastIndicesNorthToSouth, northIndicesWestToEast, vertexCount, indices, offset) {
    var vertexIndex = vertexCount;
    offset = addSkirtIndices(westIndicesSouthToNorth, vertexIndex, indices, offset);
    vertexIndex += westIndicesSouthToNorth.length;
    offset = addSkirtIndices(southIndicesEastToWest, vertexIndex, indices, offset);
    vertexIndex += southIndicesEastToWest.length;
    offset = addSkirtIndices(eastIndicesNorthToSouth, vertexIndex, indices, offset);
    vertexIndex += eastIndicesNorthToSouth.length;
    addSkirtIndices(northIndicesWestToEast, vertexIndex, indices, offset);
  };
  function getEdgeIndices(width, height) {
    var westIndicesSouthToNorth = new Array(height);
    var southIndicesEastToWest = new Array(width);
    var eastIndicesNorthToSouth = new Array(height);
    var northIndicesWestToEast = new Array(width);
    var i;
    for (i = 0; i < width; ++i) {
      northIndicesWestToEast[i] = i;
      southIndicesEastToWest[i] = width * height - 1 - i;
    }
    for (i = 0; i < height; ++i) {
      eastIndicesNorthToSouth[i] = (i + 1) * width - 1;
      westIndicesSouthToNorth[i] = (height - i - 1) * width;
    }
    return {
      westIndicesSouthToNorth: westIndicesSouthToNorth,
      southIndicesEastToWest: southIndicesEastToWest,
      eastIndicesNorthToSouth: eastIndicesNorthToSouth,
      northIndicesWestToEast: northIndicesWestToEast
    };
  }
  function addRegularGridIndices(width, height, indices, offset) {
    var index = 0;
    for (var j = 0; j < height - 1; ++j) {
      for (var i = 0; i < width - 1; ++i) {
        var upperLeft = index;
        var lowerLeft = upperLeft + width;
        var lowerRight = lowerLeft + 1;
        var upperRight = upperLeft + 1;
        indices[offset++] = upperLeft;
        indices[offset++] = lowerLeft;
        indices[offset++] = upperRight;
        indices[offset++] = upperRight;
        indices[offset++] = lowerLeft;
        indices[offset++] = lowerRight;
        ++index;
      }
      ++index;
    }
  }
  function addSkirtIndices(edgeIndices, vertexIndex, indices, offset) {
    var previousIndex = edgeIndices[0];
    var length = edgeIndices.length;
    for (var i = 1; i < length; ++i) {
      var index = edgeIndices[i];
      indices[offset++] = previousIndex;
      indices[offset++] = index;
      indices[offset++] = vertexIndex;
      indices[offset++] = vertexIndex;
      indices[offset++] = index;
      indices[offset++] = vertexIndex + 1;
      previousIndex = index;
      ++vertexIndex;
    }
    return offset;
  }

  /**
   * Specifies the quality of terrain created from heightmaps.  A value of 1.0 will
   * ensure that adjacent heightmap vertices are separated by no more than
   * {@link Globe.maximumScreenSpaceError} screen pixels and will probably go very slowly.
   * A value of 0.5 will cut the estimated level zero geometric error in half, allowing twice the
   * screen pixels between adjacent heightmap vertices and thus rendering more quickly.
   * @type {Number}
   */
  TerrainProvider.heightmapTerrainQuality = 0.25;

  /**
   * Determines an appropriate geometric error estimate when the geometry comes from a heightmap.
   *
   * @param {Ellipsoid} ellipsoid The ellipsoid to which the terrain is attached.
   * @param {Number} tileImageWidth The width, in pixels, of the heightmap associated with a single tile.
   * @param {Number} numberOfTilesAtLevelZero The number of tiles in the horizontal direction at tile level zero.
   * @returns {Number} An estimated geometric error.
   */
  TerrainProvider.getEstimatedLevelZeroGeometricErrorForAHeightmap = function (ellipsoid, tileImageWidth, numberOfTilesAtLevelZero) {
    return ellipsoid.maximumRadius * 2 * Math.PI * TerrainProvider.heightmapTerrainQuality / (tileImageWidth * numberOfTilesAtLevelZero);
  };

  /**
   * Requests the geometry for a given tile.  This function should not be called before
   * {@link TerrainProvider#ready} returns true.  The result must include terrain data and
   * may optionally include a water mask and an indication of which child tiles are available.
   * @function
   *
   * @param {Number} x The X coordinate of the tile for which to request geometry.
   * @param {Number} y The Y coordinate of the tile for which to request geometry.
   * @param {Number} level The level of the tile for which to request geometry.
   * @param {Request} [request] The request object. Intended for internal use only.
   *
   * @returns {Promise.<TerrainData>|undefined} A promise for the requested geometry.  If this method
   *          returns undefined instead of a promise, it is an indication that too many requests are already
   *          pending and the request will be retried later.
   */
  TerrainProvider.prototype.requestTileGeometry = Check.DeveloperError.throwInstantiationError;

  /**
   * Gets the maximum geometric error allowed in a tile at a given level.  This function should not be
   * called before {@link TerrainProvider#ready} returns true.
   * @function
   *
   * @param {Number} level The tile level for which to get the maximum geometric error.
   * @returns {Number} The maximum geometric error.
   */
  TerrainProvider.prototype.getLevelMaximumGeometricError = Check.DeveloperError.throwInstantiationError;

  /**
   * Determines whether data for a tile is available to be loaded.
   * @function
   *
   * @param {Number} x The X coordinate of the tile for which to request geometry.
   * @param {Number} y The Y coordinate of the tile for which to request geometry.
   * @param {Number} level The level of the tile for which to request geometry.
   * @returns {Boolean|undefined} Undefined if not supported by the terrain provider, otherwise true or false.
   */
  TerrainProvider.prototype.getTileDataAvailable = Check.DeveloperError.throwInstantiationError;

  /**
   * Makes sure we load availability data for a tile
   * @function
   *
   * @param {Number} x The X coordinate of the tile for which to request geometry.
   * @param {Number} y The Y coordinate of the tile for which to request geometry.
   * @param {Number} level The level of the tile for which to request geometry.
   * @returns {undefined|Promise<void>} Undefined if nothing need to be loaded or a Promise that resolves when all required tiles are loaded
   */
  TerrainProvider.prototype.loadTileDataAvailability = Check.DeveloperError.throwInstantiationError;

  /**
   * A function that is called when an error occurs.
   * @callback TerrainProvider.ErrorEvent
   *
   * @this TerrainProvider
   * @param {TileProviderError} err An object holding details about the error that occurred.
   */

  var maxShort = 32767;
  var cartesian3Scratch = new Matrix3.Cartesian3();
  var scratchMinimum = new Matrix3.Cartesian3();
  var scratchMaximum = new Matrix3.Cartesian3();
  var cartographicScratch = new Matrix3.Cartographic();
  var toPack = new Matrix2.Cartesian2();
  function createVerticesFromQuantizedTerrainMesh(parameters, transferableObjects) {
    var quantizedVertices = parameters.quantizedVertices;
    var quantizedVertexCount = quantizedVertices.length / 3;
    var octEncodedNormals = parameters.octEncodedNormals;
    var edgeVertexCount = parameters.westIndices.length + parameters.eastIndices.length + parameters.southIndices.length + parameters.northIndices.length;
    var includeWebMercatorT = parameters.includeWebMercatorT;
    var exaggeration = parameters.exaggeration;
    var exaggerationRelativeHeight = parameters.exaggerationRelativeHeight;
    var hasExaggeration = exaggeration !== 1.0;
    var includeGeodeticSurfaceNormals = hasExaggeration;
    var rectangle = Matrix2.Rectangle.clone(parameters.rectangle);
    var west = rectangle.west;
    var south = rectangle.south;
    var east = rectangle.east;
    var north = rectangle.north;
    var ellipsoid = Matrix3.Ellipsoid.clone(parameters.ellipsoid);
    var minimumHeight = parameters.minimumHeight;
    var maximumHeight = parameters.maximumHeight;
    var center = parameters.relativeToCenter;
    var fromENU = Transforms.Transforms.eastNorthUpToFixedFrame(center, ellipsoid);
    var toENU = Matrix2.Matrix4.inverseTransformation(fromENU, new Matrix2.Matrix4());
    var southMercatorY;
    var oneOverMercatorHeight;
    if (includeWebMercatorT) {
      southMercatorY = WebMercatorProjection.WebMercatorProjection.geodeticLatitudeToMercatorAngle(south);
      oneOverMercatorHeight = 1.0 / (WebMercatorProjection.WebMercatorProjection.geodeticLatitudeToMercatorAngle(north) - southMercatorY);
    }
    var uBuffer = quantizedVertices.subarray(0, quantizedVertexCount);
    var vBuffer = quantizedVertices.subarray(quantizedVertexCount, 2 * quantizedVertexCount);
    var heightBuffer = quantizedVertices.subarray(quantizedVertexCount * 2, 3 * quantizedVertexCount);
    var hasVertexNormals = defaultValue.defined(octEncodedNormals);
    var uvs = new Array(quantizedVertexCount);
    var heights = new Array(quantizedVertexCount);
    var positions = new Array(quantizedVertexCount);
    var webMercatorTs = includeWebMercatorT ? new Array(quantizedVertexCount) : [];
    var geodeticSurfaceNormals = includeGeodeticSurfaceNormals ? new Array(quantizedVertexCount) : [];
    var minimum = scratchMinimum;
    minimum.x = Number.POSITIVE_INFINITY;
    minimum.y = Number.POSITIVE_INFINITY;
    minimum.z = Number.POSITIVE_INFINITY;
    var maximum = scratchMaximum;
    maximum.x = Number.NEGATIVE_INFINITY;
    maximum.y = Number.NEGATIVE_INFINITY;
    maximum.z = Number.NEGATIVE_INFINITY;
    var minLongitude = Number.POSITIVE_INFINITY;
    var maxLongitude = Number.NEGATIVE_INFINITY;
    var minLatitude = Number.POSITIVE_INFINITY;
    var maxLatitude = Number.NEGATIVE_INFINITY;
    for (var i = 0; i < quantizedVertexCount; ++i) {
      var rawU = uBuffer[i];
      var rawV = vBuffer[i];
      var u = rawU / maxShort;
      var v = rawV / maxShort;
      var height = Math$1.CesiumMath.lerp(minimumHeight, maximumHeight, heightBuffer[i] / maxShort);
      cartographicScratch.longitude = Math$1.CesiumMath.lerp(west, east, u);
      cartographicScratch.latitude = Math$1.CesiumMath.lerp(south, north, v);
      cartographicScratch.height = height;
      minLongitude = Math.min(cartographicScratch.longitude, minLongitude);
      maxLongitude = Math.max(cartographicScratch.longitude, maxLongitude);
      minLatitude = Math.min(cartographicScratch.latitude, minLatitude);
      maxLatitude = Math.max(cartographicScratch.latitude, maxLatitude);
      var position = ellipsoid.cartographicToCartesian(cartographicScratch);
      uvs[i] = new Matrix2.Cartesian2(u, v);
      heights[i] = height;
      positions[i] = position;
      if (includeWebMercatorT) {
        webMercatorTs[i] = (WebMercatorProjection.WebMercatorProjection.geodeticLatitudeToMercatorAngle(cartographicScratch.latitude) - southMercatorY) * oneOverMercatorHeight;
      }
      if (includeGeodeticSurfaceNormals) {
        geodeticSurfaceNormals[i] = ellipsoid.geodeticSurfaceNormal(position);
      }
      Matrix2.Matrix4.multiplyByPoint(toENU, position, cartesian3Scratch);
      Matrix3.Cartesian3.minimumByComponent(cartesian3Scratch, minimum, minimum);
      Matrix3.Cartesian3.maximumByComponent(cartesian3Scratch, maximum, maximum);
    }
    var westIndicesSouthToNorth = copyAndSort(parameters.westIndices, function (a, b) {
      return uvs[a].y - uvs[b].y;
    });
    var eastIndicesNorthToSouth = copyAndSort(parameters.eastIndices, function (a, b) {
      return uvs[b].y - uvs[a].y;
    });
    var southIndicesEastToWest = copyAndSort(parameters.southIndices, function (a, b) {
      return uvs[b].x - uvs[a].x;
    });
    var northIndicesWestToEast = copyAndSort(parameters.northIndices, function (a, b) {
      return uvs[a].x - uvs[b].x;
    });
    var occludeePointInScaledSpace;
    if (minimumHeight < 0.0) {
      // Horizon culling point needs to be recomputed since the tile is at least partly under the ellipsoid.
      var occluder = new TerrainEncoding.EllipsoidalOccluder(ellipsoid);
      occludeePointInScaledSpace = occluder.computeHorizonCullingPointPossiblyUnderEllipsoid(center, positions, minimumHeight);
    }
    var hMin = minimumHeight;
    hMin = Math.min(hMin, findMinMaxSkirts(parameters.westIndices, parameters.westSkirtHeight, heights, uvs, rectangle, ellipsoid, toENU, minimum, maximum));
    hMin = Math.min(hMin, findMinMaxSkirts(parameters.southIndices, parameters.southSkirtHeight, heights, uvs, rectangle, ellipsoid, toENU, minimum, maximum));
    hMin = Math.min(hMin, findMinMaxSkirts(parameters.eastIndices, parameters.eastSkirtHeight, heights, uvs, rectangle, ellipsoid, toENU, minimum, maximum));
    hMin = Math.min(hMin, findMinMaxSkirts(parameters.northIndices, parameters.northSkirtHeight, heights, uvs, rectangle, ellipsoid, toENU, minimum, maximum));
    var aaBox = new AxisAlignedBoundingBox.AxisAlignedBoundingBox(minimum, maximum, center);
    var encoding = new TerrainEncoding.TerrainEncoding(center, aaBox, hMin, maximumHeight, fromENU, hasVertexNormals, includeWebMercatorT, includeGeodeticSurfaceNormals, exaggeration, exaggerationRelativeHeight);
    var vertexStride = encoding.stride;
    var size = quantizedVertexCount * vertexStride + edgeVertexCount * vertexStride;
    var vertexBuffer = new Float32Array(size);
    var bufferIndex = 0;
    for (var j = 0; j < quantizedVertexCount; ++j) {
      if (hasVertexNormals) {
        var n = j * 2.0;
        toPack.x = octEncodedNormals[n];
        toPack.y = octEncodedNormals[n + 1];
      }
      bufferIndex = encoding.encode(vertexBuffer, bufferIndex, positions[j], uvs[j], heights[j], toPack, webMercatorTs[j], geodeticSurfaceNormals[j]);
    }
    var edgeTriangleCount = Math.max(0, (edgeVertexCount - 4) * 2);
    var indexBufferLength = parameters.indices.length + edgeTriangleCount * 3;
    var indexBuffer = IndexDatatype.IndexDatatype.createTypedArray(quantizedVertexCount + edgeVertexCount, indexBufferLength);
    indexBuffer.set(parameters.indices, 0);
    var percentage = 0.0001;
    var lonOffset = (maxLongitude - minLongitude) * percentage;
    var latOffset = (maxLatitude - minLatitude) * percentage;
    var westLongitudeOffset = -lonOffset;
    var westLatitudeOffset = 0.0;
    var eastLongitudeOffset = lonOffset;
    var eastLatitudeOffset = 0.0;
    var northLongitudeOffset = 0.0;
    var northLatitudeOffset = latOffset;
    var southLongitudeOffset = 0.0;
    var southLatitudeOffset = -latOffset;

    // Add skirts.
    var vertexBufferIndex = quantizedVertexCount * vertexStride;
    addSkirt(vertexBuffer, vertexBufferIndex, westIndicesSouthToNorth, encoding, heights, uvs, octEncodedNormals, ellipsoid, rectangle, parameters.westSkirtHeight, southMercatorY, oneOverMercatorHeight, westLongitudeOffset, westLatitudeOffset);
    vertexBufferIndex += parameters.westIndices.length * vertexStride;
    addSkirt(vertexBuffer, vertexBufferIndex, southIndicesEastToWest, encoding, heights, uvs, octEncodedNormals, ellipsoid, rectangle, parameters.southSkirtHeight, southMercatorY, oneOverMercatorHeight, southLongitudeOffset, southLatitudeOffset);
    vertexBufferIndex += parameters.southIndices.length * vertexStride;
    addSkirt(vertexBuffer, vertexBufferIndex, eastIndicesNorthToSouth, encoding, heights, uvs, octEncodedNormals, ellipsoid, rectangle, parameters.eastSkirtHeight, southMercatorY, oneOverMercatorHeight, eastLongitudeOffset, eastLatitudeOffset);
    vertexBufferIndex += parameters.eastIndices.length * vertexStride;
    addSkirt(vertexBuffer, vertexBufferIndex, northIndicesWestToEast, encoding, heights, uvs, octEncodedNormals, ellipsoid, rectangle, parameters.northSkirtHeight, southMercatorY, oneOverMercatorHeight, northLongitudeOffset, northLatitudeOffset);
    TerrainProvider.addSkirtIndices(westIndicesSouthToNorth, southIndicesEastToWest, eastIndicesNorthToSouth, northIndicesWestToEast, quantizedVertexCount, indexBuffer, parameters.indices.length);
    transferableObjects.push(vertexBuffer.buffer, indexBuffer.buffer);
    return {
      vertices: vertexBuffer.buffer,
      indices: indexBuffer.buffer,
      westIndicesSouthToNorth: westIndicesSouthToNorth,
      southIndicesEastToWest: southIndicesEastToWest,
      eastIndicesNorthToSouth: eastIndicesNorthToSouth,
      northIndicesWestToEast: northIndicesWestToEast,
      vertexStride: vertexStride,
      center: center,
      minimumHeight: minimumHeight,
      maximumHeight: maximumHeight,
      occludeePointInScaledSpace: occludeePointInScaledSpace,
      encoding: encoding,
      indexCountWithoutSkirts: parameters.indices.length
    };
  }
  function findMinMaxSkirts(edgeIndices, edgeHeight, heights, uvs, rectangle, ellipsoid, toENU, minimum, maximum) {
    var hMin = Number.POSITIVE_INFINITY;
    var north = rectangle.north;
    var south = rectangle.south;
    var east = rectangle.east;
    var west = rectangle.west;
    if (east < west) {
      east += Math$1.CesiumMath.TWO_PI;
    }
    var length = edgeIndices.length;
    for (var i = 0; i < length; ++i) {
      var index = edgeIndices[i];
      var h = heights[index];
      var uv = uvs[index];
      cartographicScratch.longitude = Math$1.CesiumMath.lerp(west, east, uv.x);
      cartographicScratch.latitude = Math$1.CesiumMath.lerp(south, north, uv.y);
      cartographicScratch.height = h - edgeHeight;
      var position = ellipsoid.cartographicToCartesian(cartographicScratch, cartesian3Scratch);
      Matrix2.Matrix4.multiplyByPoint(toENU, position, position);
      Matrix3.Cartesian3.minimumByComponent(position, minimum, minimum);
      Matrix3.Cartesian3.maximumByComponent(position, maximum, maximum);
      hMin = Math.min(hMin, cartographicScratch.height);
    }
    return hMin;
  }
  function addSkirt(vertexBuffer, vertexBufferIndex, edgeVertices, encoding, heights, uvs, octEncodedNormals, ellipsoid, rectangle, skirtLength, southMercatorY, oneOverMercatorHeight, longitudeOffset, latitudeOffset) {
    var hasVertexNormals = defaultValue.defined(octEncodedNormals);
    var north = rectangle.north;
    var south = rectangle.south;
    var east = rectangle.east;
    var west = rectangle.west;
    if (east < west) {
      east += Math$1.CesiumMath.TWO_PI;
    }
    var length = edgeVertices.length;
    for (var i = 0; i < length; ++i) {
      var index = edgeVertices[i];
      var h = heights[index];
      var uv = uvs[index];
      cartographicScratch.longitude = Math$1.CesiumMath.lerp(west, east, uv.x) + longitudeOffset;
      cartographicScratch.latitude = Math$1.CesiumMath.lerp(south, north, uv.y) + latitudeOffset;
      cartographicScratch.height = h - skirtLength;
      var position = ellipsoid.cartographicToCartesian(cartographicScratch, cartesian3Scratch);
      if (hasVertexNormals) {
        var n = index * 2.0;
        toPack.x = octEncodedNormals[n];
        toPack.y = octEncodedNormals[n + 1];
      }
      var webMercatorT = void 0;
      if (encoding.hasWebMercatorT) {
        webMercatorT = (WebMercatorProjection.WebMercatorProjection.geodeticLatitudeToMercatorAngle(cartographicScratch.latitude) - southMercatorY) * oneOverMercatorHeight;
      }
      var geodeticSurfaceNormal = void 0;
      if (encoding.hasGeodeticSurfaceNormals) {
        geodeticSurfaceNormal = ellipsoid.geodeticSurfaceNormal(position);
      }
      vertexBufferIndex = encoding.encode(vertexBuffer, vertexBufferIndex, position, uv, cartographicScratch.height, toPack, webMercatorT, geodeticSurfaceNormal);
    }
  }
  function copyAndSort(typedArray, comparator) {
    var copy;
    if (typeof typedArray.slice === "function") {
      copy = typedArray.slice();
      if (typeof copy.sort !== "function") {
        // Sliced typed array isn't sortable, so we can't use it.
        copy = undefined;
      }
    }
    if (!defaultValue.defined(copy)) {
      copy = Array.prototype.slice.call(typedArray);
    }
    copy.sort(comparator);
    return copy;
  }
  var createVerticesFromQuantizedTerrainMesh$1 = createTaskProcessorWorker(createVerticesFromQuantizedTerrainMesh);
  return createVerticesFromQuantizedTerrainMesh$1;
});