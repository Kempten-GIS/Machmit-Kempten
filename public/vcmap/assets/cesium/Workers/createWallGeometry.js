define(['./defaultValue-0a909f67', './Matrix3-315394f6', './Transforms-40229881', './ComponentDatatype-f7b11d02', './Check-666ab1a0', './GeometryAttribute-7d6f1732', './GeometryAttributes-f06a2792', './IndexDatatype-a55ceaa1', './Math-2dbd6b93', './VertexFormat-6b480673', './WallGeometryLibrary-919eed92', './Matrix2-13178034', './RuntimeError-06c93819', './combine-ca22a614', './WebGLConstants-a8cc3e8c', './arrayRemoveDuplicates-c2038105', './PolylinePipeline-32f36d2a', './EllipsoidGeodesic-98c62a56', './EllipsoidRhumbLine-19756602', './IntersectionTests-f6e6bd8a', './Plane-900aa728'], function (defaultValue, Matrix3, Transforms, ComponentDatatype, Check, GeometryAttribute, GeometryAttributes, IndexDatatype, Math, VertexFormat, WallGeometryLibrary, Matrix2, RuntimeError, combine, WebGLConstants, arrayRemoveDuplicates, PolylinePipeline, EllipsoidGeodesic, EllipsoidRhumbLine, IntersectionTests, Plane) {
  'use strict';

  var scratchCartesian3Position1 = new Matrix3.Cartesian3();
  var scratchCartesian3Position2 = new Matrix3.Cartesian3();
  var scratchCartesian3Position4 = new Matrix3.Cartesian3();
  var scratchCartesian3Position5 = new Matrix3.Cartesian3();
  var scratchBitangent = new Matrix3.Cartesian3();
  var scratchTangent = new Matrix3.Cartesian3();
  var scratchNormal = new Matrix3.Cartesian3();

  /**
   * A description of a wall, which is similar to a KML line string. A wall is defined by a series of points,
   * which extrude down to the ground. Optionally, they can extrude downwards to a specified height.
   *
   * @alias WallGeometry
   * @constructor
   *
   * @param {Object} options Object with the following properties:
   * @param {Cartesian3[]} options.positions An array of Cartesian objects, which are the points of the wall.
   * @param {Number} [options.granularity=CesiumMath.RADIANS_PER_DEGREE] The distance, in radians, between each latitude and longitude. Determines the number of positions in the buffer.
   * @param {Number[]} [options.maximumHeights] An array parallel to <code>positions</code> that give the maximum height of the
   *        wall at <code>positions</code>. If undefined, the height of each position in used.
   * @param {Number[]} [options.minimumHeights] An array parallel to <code>positions</code> that give the minimum height of the
   *        wall at <code>positions</code>. If undefined, the height at each position is 0.0.
   * @param {Ellipsoid} [options.ellipsoid=Ellipsoid.WGS84] The ellipsoid for coordinate manipulation
   * @param {VertexFormat} [options.vertexFormat=VertexFormat.DEFAULT] The vertex attributes to be computed.
   *
   * @exception {DeveloperError} positions length must be greater than or equal to 2.
   * @exception {DeveloperError} positions and maximumHeights must have the same length.
   * @exception {DeveloperError} positions and minimumHeights must have the same length.
   *
   * @see WallGeometry#createGeometry
   * @see WallGeometry#fromConstantHeight
   *
   * @demo {@link https://sandcastle.cesium.com/index.html?src=Wall.html|Cesium Sandcastle Wall Demo}
   *
   * @example
   * // create a wall that spans from ground level to 10000 meters
   * const wall = new Cesium.WallGeometry({
   *   positions : Cesium.Cartesian3.fromDegreesArrayHeights([
   *     19.0, 47.0, 10000.0,
   *     19.0, 48.0, 10000.0,
   *     20.0, 48.0, 10000.0,
   *     20.0, 47.0, 10000.0,
   *     19.0, 47.0, 10000.0
   *   ])
   * });
   * const geometry = Cesium.WallGeometry.createGeometry(wall);
   */
  function WallGeometry(options) {
    options = defaultValue.defaultValue(options, defaultValue.defaultValue.EMPTY_OBJECT);
    var wallPositions = options.positions;
    var maximumHeights = options.maximumHeights;
    var minimumHeights = options.minimumHeights;

    //>>includeStart('debug', pragmas.debug);
    if (!defaultValue.defined(wallPositions)) {
      throw new Check.DeveloperError("options.positions is required.");
    }
    if (defaultValue.defined(maximumHeights) && maximumHeights.length !== wallPositions.length) {
      throw new Check.DeveloperError("options.positions and options.maximumHeights must have the same length.");
    }
    if (defaultValue.defined(minimumHeights) && minimumHeights.length !== wallPositions.length) {
      throw new Check.DeveloperError("options.positions and options.minimumHeights must have the same length.");
    }
    //>>includeEnd('debug');

    var vertexFormat = defaultValue.defaultValue(options.vertexFormat, VertexFormat.VertexFormat.DEFAULT);
    var granularity = defaultValue.defaultValue(options.granularity, Math.CesiumMath.RADIANS_PER_DEGREE);
    var ellipsoid = defaultValue.defaultValue(options.ellipsoid, Matrix3.Ellipsoid.WGS84);
    this._positions = wallPositions;
    this._minimumHeights = minimumHeights;
    this._maximumHeights = maximumHeights;
    this._vertexFormat = VertexFormat.VertexFormat.clone(vertexFormat);
    this._granularity = granularity;
    this._ellipsoid = Matrix3.Ellipsoid.clone(ellipsoid);
    this._workerName = "createWallGeometry";
    var numComponents = 1 + wallPositions.length * Matrix3.Cartesian3.packedLength + 2;
    if (defaultValue.defined(minimumHeights)) {
      numComponents += minimumHeights.length;
    }
    if (defaultValue.defined(maximumHeights)) {
      numComponents += maximumHeights.length;
    }

    /**
     * The number of elements used to pack the object into an array.
     * @type {Number}
     */
    this.packedLength = numComponents + Matrix3.Ellipsoid.packedLength + VertexFormat.VertexFormat.packedLength + 1;
  }

  /**
   * Stores the provided instance into the provided array.
   *
   * @param {WallGeometry} value The value to pack.
   * @param {Number[]} array The array to pack into.
   * @param {Number} [startingIndex=0] The index into the array at which to start packing the elements.
   *
   * @returns {Number[]} The array that was packed into
   */
  WallGeometry.pack = function (value, array, startingIndex) {
    //>>includeStart('debug', pragmas.debug);
    if (!defaultValue.defined(value)) {
      throw new Check.DeveloperError("value is required");
    }
    if (!defaultValue.defined(array)) {
      throw new Check.DeveloperError("array is required");
    }
    //>>includeEnd('debug');

    startingIndex = defaultValue.defaultValue(startingIndex, 0);
    var i;
    var positions = value._positions;
    var length = positions.length;
    array[startingIndex++] = length;
    for (i = 0; i < length; ++i, startingIndex += Matrix3.Cartesian3.packedLength) {
      Matrix3.Cartesian3.pack(positions[i], array, startingIndex);
    }
    var minimumHeights = value._minimumHeights;
    length = defaultValue.defined(minimumHeights) ? minimumHeights.length : 0;
    array[startingIndex++] = length;
    if (defaultValue.defined(minimumHeights)) {
      for (i = 0; i < length; ++i) {
        array[startingIndex++] = minimumHeights[i];
      }
    }
    var maximumHeights = value._maximumHeights;
    length = defaultValue.defined(maximumHeights) ? maximumHeights.length : 0;
    array[startingIndex++] = length;
    if (defaultValue.defined(maximumHeights)) {
      for (i = 0; i < length; ++i) {
        array[startingIndex++] = maximumHeights[i];
      }
    }
    Matrix3.Ellipsoid.pack(value._ellipsoid, array, startingIndex);
    startingIndex += Matrix3.Ellipsoid.packedLength;
    VertexFormat.VertexFormat.pack(value._vertexFormat, array, startingIndex);
    startingIndex += VertexFormat.VertexFormat.packedLength;
    array[startingIndex] = value._granularity;
    return array;
  };
  var scratchEllipsoid = Matrix3.Ellipsoid.clone(Matrix3.Ellipsoid.UNIT_SPHERE);
  var scratchVertexFormat = new VertexFormat.VertexFormat();
  var scratchOptions = {
    positions: undefined,
    minimumHeights: undefined,
    maximumHeights: undefined,
    ellipsoid: scratchEllipsoid,
    vertexFormat: scratchVertexFormat,
    granularity: undefined
  };

  /**
   * Retrieves an instance from a packed array.
   *
   * @param {Number[]} array The packed array.
   * @param {Number} [startingIndex=0] The starting index of the element to be unpacked.
   * @param {WallGeometry} [result] The object into which to store the result.
   * @returns {WallGeometry} The modified result parameter or a new WallGeometry instance if one was not provided.
   */
  WallGeometry.unpack = function (array, startingIndex, result) {
    //>>includeStart('debug', pragmas.debug);
    if (!defaultValue.defined(array)) {
      throw new Check.DeveloperError("array is required");
    }
    //>>includeEnd('debug');

    startingIndex = defaultValue.defaultValue(startingIndex, 0);
    var i;
    var length = array[startingIndex++];
    var positions = new Array(length);
    for (i = 0; i < length; ++i, startingIndex += Matrix3.Cartesian3.packedLength) {
      positions[i] = Matrix3.Cartesian3.unpack(array, startingIndex);
    }
    length = array[startingIndex++];
    var minimumHeights;
    if (length > 0) {
      minimumHeights = new Array(length);
      for (i = 0; i < length; ++i) {
        minimumHeights[i] = array[startingIndex++];
      }
    }
    length = array[startingIndex++];
    var maximumHeights;
    if (length > 0) {
      maximumHeights = new Array(length);
      for (i = 0; i < length; ++i) {
        maximumHeights[i] = array[startingIndex++];
      }
    }
    var ellipsoid = Matrix3.Ellipsoid.unpack(array, startingIndex, scratchEllipsoid);
    startingIndex += Matrix3.Ellipsoid.packedLength;
    var vertexFormat = VertexFormat.VertexFormat.unpack(array, startingIndex, scratchVertexFormat);
    startingIndex += VertexFormat.VertexFormat.packedLength;
    var granularity = array[startingIndex];
    if (!defaultValue.defined(result)) {
      scratchOptions.positions = positions;
      scratchOptions.minimumHeights = minimumHeights;
      scratchOptions.maximumHeights = maximumHeights;
      scratchOptions.granularity = granularity;
      return new WallGeometry(scratchOptions);
    }
    result._positions = positions;
    result._minimumHeights = minimumHeights;
    result._maximumHeights = maximumHeights;
    result._ellipsoid = Matrix3.Ellipsoid.clone(ellipsoid, result._ellipsoid);
    result._vertexFormat = VertexFormat.VertexFormat.clone(vertexFormat, result._vertexFormat);
    result._granularity = granularity;
    return result;
  };

  /**
   * A description of a wall, which is similar to a KML line string. A wall is defined by a series of points,
   * which extrude down to the ground. Optionally, they can extrude downwards to a specified height.
   *
   * @param {Object} options Object with the following properties:
   * @param {Cartesian3[]} options.positions An array of Cartesian objects, which are the points of the wall.
   * @param {Number} [options.maximumHeight] A constant that defines the maximum height of the
   *        wall at <code>positions</code>. If undefined, the height of each position in used.
   * @param {Number} [options.minimumHeight] A constant that defines the minimum height of the
   *        wall at <code>positions</code>. If undefined, the height at each position is 0.0.
   * @param {Ellipsoid} [options.ellipsoid=Ellipsoid.WGS84] The ellipsoid for coordinate manipulation
   * @param {VertexFormat} [options.vertexFormat=VertexFormat.DEFAULT] The vertex attributes to be computed.
   * @returns {WallGeometry}
   *
   *
   * @example
   * // create a wall that spans from 10000 meters to 20000 meters
   * const wall = Cesium.WallGeometry.fromConstantHeights({
   *   positions : Cesium.Cartesian3.fromDegreesArray([
   *     19.0, 47.0,
   *     19.0, 48.0,
   *     20.0, 48.0,
   *     20.0, 47.0,
   *     19.0, 47.0,
   *   ]),
   *   minimumHeight : 20000.0,
   *   maximumHeight : 10000.0
   * });
   * const geometry = Cesium.WallGeometry.createGeometry(wall);
   *
   * @see WallGeometry#createGeometry
   */
  WallGeometry.fromConstantHeights = function (options) {
    options = defaultValue.defaultValue(options, defaultValue.defaultValue.EMPTY_OBJECT);
    var positions = options.positions;

    //>>includeStart('debug', pragmas.debug);
    if (!defaultValue.defined(positions)) {
      throw new Check.DeveloperError("options.positions is required.");
    }
    //>>includeEnd('debug');

    var minHeights;
    var maxHeights;
    var min = options.minimumHeight;
    var max = options.maximumHeight;
    var doMin = defaultValue.defined(min);
    var doMax = defaultValue.defined(max);
    if (doMin || doMax) {
      var length = positions.length;
      minHeights = doMin ? new Array(length) : undefined;
      maxHeights = doMax ? new Array(length) : undefined;
      for (var i = 0; i < length; ++i) {
        if (doMin) {
          minHeights[i] = min;
        }
        if (doMax) {
          maxHeights[i] = max;
        }
      }
    }
    var newOptions = {
      positions: positions,
      maximumHeights: maxHeights,
      minimumHeights: minHeights,
      ellipsoid: options.ellipsoid,
      vertexFormat: options.vertexFormat
    };
    return new WallGeometry(newOptions);
  };

  /**
   * Computes the geometric representation of a wall, including its vertices, indices, and a bounding sphere.
   *
   * @param {WallGeometry} wallGeometry A description of the wall.
   * @returns {Geometry|undefined} The computed vertices and indices.
   */
  WallGeometry.createGeometry = function (wallGeometry) {
    var wallPositions = wallGeometry._positions;
    var minimumHeights = wallGeometry._minimumHeights;
    var maximumHeights = wallGeometry._maximumHeights;
    var vertexFormat = wallGeometry._vertexFormat;
    var granularity = wallGeometry._granularity;
    var ellipsoid = wallGeometry._ellipsoid;
    var pos = WallGeometryLibrary.WallGeometryLibrary.computePositions(ellipsoid, wallPositions, maximumHeights, minimumHeights, granularity, true);
    if (!defaultValue.defined(pos)) {
      return;
    }
    var bottomPositions = pos.bottomPositions;
    var topPositions = pos.topPositions;
    var numCorners = pos.numCorners;
    var length = topPositions.length;
    var size = length * 2;
    var positions = vertexFormat.position ? new Float64Array(size) : undefined;
    var normals = vertexFormat.normal ? new Float32Array(size) : undefined;
    var tangents = vertexFormat.tangent ? new Float32Array(size) : undefined;
    var bitangents = vertexFormat.bitangent ? new Float32Array(size) : undefined;
    var textureCoordinates = vertexFormat.st ? new Float32Array(size / 3 * 2) : undefined;
    var positionIndex = 0;
    var normalIndex = 0;
    var bitangentIndex = 0;
    var tangentIndex = 0;
    var stIndex = 0;

    // add lower and upper points one after the other, lower
    // points being even and upper points being odd
    var normal = scratchNormal;
    var tangent = scratchTangent;
    var bitangent = scratchBitangent;
    var recomputeNormal = true;
    length /= 3;
    var i;
    var s = 0;
    var ds = 1 / (length - numCorners - 1);
    for (i = 0; i < length; ++i) {
      var i3 = i * 3;
      var topPosition = Matrix3.Cartesian3.fromArray(topPositions, i3, scratchCartesian3Position1);
      var bottomPosition = Matrix3.Cartesian3.fromArray(bottomPositions, i3, scratchCartesian3Position2);
      if (vertexFormat.position) {
        // insert the lower point
        positions[positionIndex++] = bottomPosition.x;
        positions[positionIndex++] = bottomPosition.y;
        positions[positionIndex++] = bottomPosition.z;

        // insert the upper point
        positions[positionIndex++] = topPosition.x;
        positions[positionIndex++] = topPosition.y;
        positions[positionIndex++] = topPosition.z;
      }
      if (vertexFormat.st) {
        textureCoordinates[stIndex++] = s;
        textureCoordinates[stIndex++] = 0.0;
        textureCoordinates[stIndex++] = s;
        textureCoordinates[stIndex++] = 1.0;
      }
      if (vertexFormat.normal || vertexFormat.tangent || vertexFormat.bitangent) {
        var nextTop = Matrix3.Cartesian3.clone(Matrix3.Cartesian3.ZERO, scratchCartesian3Position5);
        var groundPosition = Matrix3.Cartesian3.subtract(topPosition, ellipsoid.geodeticSurfaceNormal(topPosition, scratchCartesian3Position2), scratchCartesian3Position2);
        if (i + 1 < length) {
          nextTop = Matrix3.Cartesian3.fromArray(topPositions, i3 + 3, scratchCartesian3Position5);
        }
        if (recomputeNormal) {
          var scalednextPosition = Matrix3.Cartesian3.subtract(nextTop, topPosition, scratchCartesian3Position4);
          var scaledGroundPosition = Matrix3.Cartesian3.subtract(groundPosition, topPosition, scratchCartesian3Position1);
          normal = Matrix3.Cartesian3.normalize(Matrix3.Cartesian3.cross(scaledGroundPosition, scalednextPosition, normal), normal);
          recomputeNormal = false;
        }
        if (Matrix3.Cartesian3.equalsEpsilon(topPosition, nextTop, Math.CesiumMath.EPSILON10)) {
          recomputeNormal = true;
        } else {
          s += ds;
          if (vertexFormat.tangent) {
            tangent = Matrix3.Cartesian3.normalize(Matrix3.Cartesian3.subtract(nextTop, topPosition, tangent), tangent);
          }
          if (vertexFormat.bitangent) {
            bitangent = Matrix3.Cartesian3.normalize(Matrix3.Cartesian3.cross(normal, tangent, bitangent), bitangent);
          }
        }
        if (vertexFormat.normal) {
          normals[normalIndex++] = normal.x;
          normals[normalIndex++] = normal.y;
          normals[normalIndex++] = normal.z;
          normals[normalIndex++] = normal.x;
          normals[normalIndex++] = normal.y;
          normals[normalIndex++] = normal.z;
        }
        if (vertexFormat.tangent) {
          tangents[tangentIndex++] = tangent.x;
          tangents[tangentIndex++] = tangent.y;
          tangents[tangentIndex++] = tangent.z;
          tangents[tangentIndex++] = tangent.x;
          tangents[tangentIndex++] = tangent.y;
          tangents[tangentIndex++] = tangent.z;
        }
        if (vertexFormat.bitangent) {
          bitangents[bitangentIndex++] = bitangent.x;
          bitangents[bitangentIndex++] = bitangent.y;
          bitangents[bitangentIndex++] = bitangent.z;
          bitangents[bitangentIndex++] = bitangent.x;
          bitangents[bitangentIndex++] = bitangent.y;
          bitangents[bitangentIndex++] = bitangent.z;
        }
      }
    }
    var attributes = new GeometryAttributes.GeometryAttributes();
    if (vertexFormat.position) {
      attributes.position = new GeometryAttribute.GeometryAttribute({
        componentDatatype: ComponentDatatype.ComponentDatatype.DOUBLE,
        componentsPerAttribute: 3,
        values: positions
      });
    }
    if (vertexFormat.normal) {
      attributes.normal = new GeometryAttribute.GeometryAttribute({
        componentDatatype: ComponentDatatype.ComponentDatatype.FLOAT,
        componentsPerAttribute: 3,
        values: normals
      });
    }
    if (vertexFormat.tangent) {
      attributes.tangent = new GeometryAttribute.GeometryAttribute({
        componentDatatype: ComponentDatatype.ComponentDatatype.FLOAT,
        componentsPerAttribute: 3,
        values: tangents
      });
    }
    if (vertexFormat.bitangent) {
      attributes.bitangent = new GeometryAttribute.GeometryAttribute({
        componentDatatype: ComponentDatatype.ComponentDatatype.FLOAT,
        componentsPerAttribute: 3,
        values: bitangents
      });
    }
    if (vertexFormat.st) {
      attributes.st = new GeometryAttribute.GeometryAttribute({
        componentDatatype: ComponentDatatype.ComponentDatatype.FLOAT,
        componentsPerAttribute: 2,
        values: textureCoordinates
      });
    }

    // prepare the side walls, two triangles for each wall
    //
    //    A (i+1)  B (i+3) E
    //    +--------+-------+
    //    |      / |      /|    triangles:  A C B
    //    |     /  |     / |                B C D
    //    |    /   |    /  |
    //    |   /    |   /   |
    //    |  /     |  /    |
    //    | /      | /     |
    //    +--------+-------+
    //    C (i)    D (i+2) F
    //

    var numVertices = size / 3;
    size -= 6 * (numCorners + 1);
    var indices = IndexDatatype.IndexDatatype.createTypedArray(numVertices, size);
    var edgeIndex = 0;
    for (i = 0; i < numVertices - 2; i += 2) {
      var LL = i;
      var LR = i + 2;
      var pl = Matrix3.Cartesian3.fromArray(positions, LL * 3, scratchCartesian3Position1);
      var pr = Matrix3.Cartesian3.fromArray(positions, LR * 3, scratchCartesian3Position2);
      if (Matrix3.Cartesian3.equalsEpsilon(pl, pr, Math.CesiumMath.EPSILON10)) {
        continue;
      }
      var UL = i + 1;
      var UR = i + 3;
      indices[edgeIndex++] = UL;
      indices[edgeIndex++] = LL;
      indices[edgeIndex++] = UR;
      indices[edgeIndex++] = UR;
      indices[edgeIndex++] = LL;
      indices[edgeIndex++] = LR;
    }
    return new GeometryAttribute.Geometry({
      attributes: attributes,
      indices: indices,
      primitiveType: GeometryAttribute.PrimitiveType.TRIANGLES,
      boundingSphere: new Transforms.BoundingSphere.fromVertices(positions)
    });
  };
  function createWallGeometry(wallGeometry, offset) {
    if (defaultValue.defined(offset)) {
      wallGeometry = WallGeometry.unpack(wallGeometry, offset);
    }
    wallGeometry._ellipsoid = Matrix3.Ellipsoid.clone(wallGeometry._ellipsoid);
    return WallGeometry.createGeometry(wallGeometry);
  }
  return createWallGeometry;
});