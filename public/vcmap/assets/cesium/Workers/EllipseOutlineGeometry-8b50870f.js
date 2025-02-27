define(['exports', './Transforms-40229881', './Matrix3-315394f6', './ComponentDatatype-f7b11d02', './defaultValue-0a909f67', './Check-666ab1a0', './EllipseGeometryLibrary-2939e1dc', './GeometryAttribute-7d6f1732', './GeometryAttributes-f06a2792', './GeometryOffsetAttribute-04332ce7', './IndexDatatype-a55ceaa1', './Math-2dbd6b93'], function (exports, Transforms, Matrix3, ComponentDatatype, defaultValue, Check, EllipseGeometryLibrary, GeometryAttribute, GeometryAttributes, GeometryOffsetAttribute, IndexDatatype, Math$1) {
  'use strict';

  var scratchCartesian1 = new Matrix3.Cartesian3();
  var boundingSphereCenter = new Matrix3.Cartesian3();
  function computeEllipse(options) {
    var center = options.center;
    boundingSphereCenter = Matrix3.Cartesian3.multiplyByScalar(options.ellipsoid.geodeticSurfaceNormal(center, boundingSphereCenter), options.height, boundingSphereCenter);
    boundingSphereCenter = Matrix3.Cartesian3.add(center, boundingSphereCenter, boundingSphereCenter);
    var boundingSphere = new Transforms.BoundingSphere(boundingSphereCenter, options.semiMajorAxis);
    var positions = EllipseGeometryLibrary.EllipseGeometryLibrary.computeEllipsePositions(options, false, true).outerPositions;
    var attributes = new GeometryAttributes.GeometryAttributes({
      position: new GeometryAttribute.GeometryAttribute({
        componentDatatype: ComponentDatatype.ComponentDatatype.DOUBLE,
        componentsPerAttribute: 3,
        values: EllipseGeometryLibrary.EllipseGeometryLibrary.raisePositionsToHeight(positions, options, false)
      })
    });
    var length = positions.length / 3;
    var indices = IndexDatatype.IndexDatatype.createTypedArray(length, length * 2);
    var index = 0;
    for (var i = 0; i < length; ++i) {
      indices[index++] = i;
      indices[index++] = (i + 1) % length;
    }
    return {
      boundingSphere: boundingSphere,
      attributes: attributes,
      indices: indices
    };
  }
  var topBoundingSphere = new Transforms.BoundingSphere();
  var bottomBoundingSphere = new Transforms.BoundingSphere();
  function computeExtrudedEllipse(options) {
    var center = options.center;
    var ellipsoid = options.ellipsoid;
    var semiMajorAxis = options.semiMajorAxis;
    var scaledNormal = Matrix3.Cartesian3.multiplyByScalar(ellipsoid.geodeticSurfaceNormal(center, scratchCartesian1), options.height, scratchCartesian1);
    topBoundingSphere.center = Matrix3.Cartesian3.add(center, scaledNormal, topBoundingSphere.center);
    topBoundingSphere.radius = semiMajorAxis;
    scaledNormal = Matrix3.Cartesian3.multiplyByScalar(ellipsoid.geodeticSurfaceNormal(center, scaledNormal), options.extrudedHeight, scaledNormal);
    bottomBoundingSphere.center = Matrix3.Cartesian3.add(center, scaledNormal, bottomBoundingSphere.center);
    bottomBoundingSphere.radius = semiMajorAxis;
    var positions = EllipseGeometryLibrary.EllipseGeometryLibrary.computeEllipsePositions(options, false, true).outerPositions;
    var attributes = new GeometryAttributes.GeometryAttributes({
      position: new GeometryAttribute.GeometryAttribute({
        componentDatatype: ComponentDatatype.ComponentDatatype.DOUBLE,
        componentsPerAttribute: 3,
        values: EllipseGeometryLibrary.EllipseGeometryLibrary.raisePositionsToHeight(positions, options, true)
      })
    });
    positions = attributes.position.values;
    var boundingSphere = Transforms.BoundingSphere.union(topBoundingSphere, bottomBoundingSphere);
    var length = positions.length / 3;
    if (defaultValue.defined(options.offsetAttribute)) {
      var applyOffset = new Uint8Array(length);
      if (options.offsetAttribute === GeometryOffsetAttribute.GeometryOffsetAttribute.TOP) {
        applyOffset = applyOffset.fill(1, 0, length / 2);
      } else {
        var offsetValue = options.offsetAttribute === GeometryOffsetAttribute.GeometryOffsetAttribute.NONE ? 0 : 1;
        applyOffset = applyOffset.fill(offsetValue);
      }
      attributes.applyOffset = new GeometryAttribute.GeometryAttribute({
        componentDatatype: ComponentDatatype.ComponentDatatype.UNSIGNED_BYTE,
        componentsPerAttribute: 1,
        values: applyOffset
      });
    }
    var numberOfVerticalLines = defaultValue.defaultValue(options.numberOfVerticalLines, 16);
    numberOfVerticalLines = Math$1.CesiumMath.clamp(numberOfVerticalLines, 0, length / 2);
    var indices = IndexDatatype.IndexDatatype.createTypedArray(length, length * 2 + numberOfVerticalLines * 2);
    length /= 2;
    var index = 0;
    var i;
    for (i = 0; i < length; ++i) {
      indices[index++] = i;
      indices[index++] = (i + 1) % length;
      indices[index++] = i + length;
      indices[index++] = (i + 1) % length + length;
    }
    var numSide;
    if (numberOfVerticalLines > 0) {
      var numSideLines = Math.min(numberOfVerticalLines, length);
      numSide = Math.round(length / numSideLines);
      var maxI = Math.min(numSide * numberOfVerticalLines, length);
      for (i = 0; i < maxI; i += numSide) {
        indices[index++] = i;
        indices[index++] = i + length;
      }
    }
    return {
      boundingSphere: boundingSphere,
      attributes: attributes,
      indices: indices
    };
  }

  /**
   * A description of the outline of an ellipse on an ellipsoid.
   *
   * @alias EllipseOutlineGeometry
   * @constructor
   *
   * @param {Object} options Object with the following properties:
   * @param {Cartesian3} options.center The ellipse's center point in the fixed frame.
   * @param {Number} options.semiMajorAxis The length of the ellipse's semi-major axis in meters.
   * @param {Number} options.semiMinorAxis The length of the ellipse's semi-minor axis in meters.
   * @param {Ellipsoid} [options.ellipsoid=Ellipsoid.WGS84] The ellipsoid the ellipse will be on.
   * @param {Number} [options.height=0.0] The distance in meters between the ellipse and the ellipsoid surface.
   * @param {Number} [options.extrudedHeight] The distance in meters between the ellipse's extruded face and the ellipsoid surface.
   * @param {Number} [options.rotation=0.0] The angle from north (counter-clockwise) in radians.
   * @param {Number} [options.granularity=0.02] The angular distance between points on the ellipse in radians.
   * @param {Number} [options.numberOfVerticalLines=16] Number of lines to draw between the top and bottom surface of an extruded ellipse.
   *
   * @exception {DeveloperError} semiMajorAxis and semiMinorAxis must be greater than zero.
   * @exception {DeveloperError} semiMajorAxis must be greater than or equal to the semiMinorAxis.
   * @exception {DeveloperError} granularity must be greater than zero.
   *
   * @see EllipseOutlineGeometry.createGeometry
   *
   * @example
   * const ellipse = new Cesium.EllipseOutlineGeometry({
   *   center : Cesium.Cartesian3.fromDegrees(-75.59777, 40.03883),
   *   semiMajorAxis : 500000.0,
   *   semiMinorAxis : 300000.0,
   *   rotation : Cesium.Math.toRadians(60.0)
   * });
   * const geometry = Cesium.EllipseOutlineGeometry.createGeometry(ellipse);
   */
  function EllipseOutlineGeometry(options) {
    options = defaultValue.defaultValue(options, defaultValue.defaultValue.EMPTY_OBJECT);
    var center = options.center;
    var ellipsoid = defaultValue.defaultValue(options.ellipsoid, Matrix3.Ellipsoid.WGS84);
    var semiMajorAxis = options.semiMajorAxis;
    var semiMinorAxis = options.semiMinorAxis;
    var granularity = defaultValue.defaultValue(options.granularity, Math$1.CesiumMath.RADIANS_PER_DEGREE);

    //>>includeStart('debug', pragmas.debug);
    if (!defaultValue.defined(center)) {
      throw new Check.DeveloperError("center is required.");
    }
    if (!defaultValue.defined(semiMajorAxis)) {
      throw new Check.DeveloperError("semiMajorAxis is required.");
    }
    if (!defaultValue.defined(semiMinorAxis)) {
      throw new Check.DeveloperError("semiMinorAxis is required.");
    }
    if (semiMajorAxis < semiMinorAxis) {
      throw new Check.DeveloperError("semiMajorAxis must be greater than or equal to the semiMinorAxis.");
    }
    if (granularity <= 0.0) {
      throw new Check.DeveloperError("granularity must be greater than zero.");
    }
    //>>includeEnd('debug');

    var height = defaultValue.defaultValue(options.height, 0.0);
    var extrudedHeight = defaultValue.defaultValue(options.extrudedHeight, height);
    this._center = Matrix3.Cartesian3.clone(center);
    this._semiMajorAxis = semiMajorAxis;
    this._semiMinorAxis = semiMinorAxis;
    this._ellipsoid = Matrix3.Ellipsoid.clone(ellipsoid);
    this._rotation = defaultValue.defaultValue(options.rotation, 0.0);
    this._height = Math.max(extrudedHeight, height);
    this._granularity = granularity;
    this._extrudedHeight = Math.min(extrudedHeight, height);
    this._numberOfVerticalLines = Math.max(defaultValue.defaultValue(options.numberOfVerticalLines, 16), 0);
    this._offsetAttribute = options.offsetAttribute;
    this._workerName = "createEllipseOutlineGeometry";
  }

  /**
   * The number of elements used to pack the object into an array.
   * @type {Number}
   */
  EllipseOutlineGeometry.packedLength = Matrix3.Cartesian3.packedLength + Matrix3.Ellipsoid.packedLength + 8;

  /**
   * Stores the provided instance into the provided array.
   *
   * @param {EllipseOutlineGeometry} value The value to pack.
   * @param {Number[]} array The array to pack into.
   * @param {Number} [startingIndex=0] The index into the array at which to start packing the elements.
   *
   * @returns {Number[]} The array that was packed into
   */
  EllipseOutlineGeometry.pack = function (value, array, startingIndex) {
    //>>includeStart('debug', pragmas.debug);
    if (!defaultValue.defined(value)) {
      throw new Check.DeveloperError("value is required");
    }
    if (!defaultValue.defined(array)) {
      throw new Check.DeveloperError("array is required");
    }
    //>>includeEnd('debug');

    startingIndex = defaultValue.defaultValue(startingIndex, 0);
    Matrix3.Cartesian3.pack(value._center, array, startingIndex);
    startingIndex += Matrix3.Cartesian3.packedLength;
    Matrix3.Ellipsoid.pack(value._ellipsoid, array, startingIndex);
    startingIndex += Matrix3.Ellipsoid.packedLength;
    array[startingIndex++] = value._semiMajorAxis;
    array[startingIndex++] = value._semiMinorAxis;
    array[startingIndex++] = value._rotation;
    array[startingIndex++] = value._height;
    array[startingIndex++] = value._granularity;
    array[startingIndex++] = value._extrudedHeight;
    array[startingIndex++] = value._numberOfVerticalLines;
    array[startingIndex] = defaultValue.defaultValue(value._offsetAttribute, -1);
    return array;
  };
  var scratchCenter = new Matrix3.Cartesian3();
  var scratchEllipsoid = new Matrix3.Ellipsoid();
  var scratchOptions = {
    center: scratchCenter,
    ellipsoid: scratchEllipsoid,
    semiMajorAxis: undefined,
    semiMinorAxis: undefined,
    rotation: undefined,
    height: undefined,
    granularity: undefined,
    extrudedHeight: undefined,
    numberOfVerticalLines: undefined,
    offsetAttribute: undefined
  };

  /**
   * Retrieves an instance from a packed array.
   *
   * @param {Number[]} array The packed array.
   * @param {Number} [startingIndex=0] The starting index of the element to be unpacked.
   * @param {EllipseOutlineGeometry} [result] The object into which to store the result.
   * @returns {EllipseOutlineGeometry} The modified result parameter or a new EllipseOutlineGeometry instance if one was not provided.
   */
  EllipseOutlineGeometry.unpack = function (array, startingIndex, result) {
    //>>includeStart('debug', pragmas.debug);
    if (!defaultValue.defined(array)) {
      throw new Check.DeveloperError("array is required");
    }
    //>>includeEnd('debug');

    startingIndex = defaultValue.defaultValue(startingIndex, 0);
    var center = Matrix3.Cartesian3.unpack(array, startingIndex, scratchCenter);
    startingIndex += Matrix3.Cartesian3.packedLength;
    var ellipsoid = Matrix3.Ellipsoid.unpack(array, startingIndex, scratchEllipsoid);
    startingIndex += Matrix3.Ellipsoid.packedLength;
    var semiMajorAxis = array[startingIndex++];
    var semiMinorAxis = array[startingIndex++];
    var rotation = array[startingIndex++];
    var height = array[startingIndex++];
    var granularity = array[startingIndex++];
    var extrudedHeight = array[startingIndex++];
    var numberOfVerticalLines = array[startingIndex++];
    var offsetAttribute = array[startingIndex];
    if (!defaultValue.defined(result)) {
      scratchOptions.height = height;
      scratchOptions.extrudedHeight = extrudedHeight;
      scratchOptions.granularity = granularity;
      scratchOptions.rotation = rotation;
      scratchOptions.semiMajorAxis = semiMajorAxis;
      scratchOptions.semiMinorAxis = semiMinorAxis;
      scratchOptions.numberOfVerticalLines = numberOfVerticalLines;
      scratchOptions.offsetAttribute = offsetAttribute === -1 ? undefined : offsetAttribute;
      return new EllipseOutlineGeometry(scratchOptions);
    }
    result._center = Matrix3.Cartesian3.clone(center, result._center);
    result._ellipsoid = Matrix3.Ellipsoid.clone(ellipsoid, result._ellipsoid);
    result._semiMajorAxis = semiMajorAxis;
    result._semiMinorAxis = semiMinorAxis;
    result._rotation = rotation;
    result._height = height;
    result._granularity = granularity;
    result._extrudedHeight = extrudedHeight;
    result._numberOfVerticalLines = numberOfVerticalLines;
    result._offsetAttribute = offsetAttribute === -1 ? undefined : offsetAttribute;
    return result;
  };

  /**
   * Computes the geometric representation of an outline of an ellipse on an ellipsoid, including its vertices, indices, and a bounding sphere.
   *
   * @param {EllipseOutlineGeometry} ellipseGeometry A description of the ellipse.
   * @returns {Geometry|undefined} The computed vertices and indices.
   */
  EllipseOutlineGeometry.createGeometry = function (ellipseGeometry) {
    if (ellipseGeometry._semiMajorAxis <= 0.0 || ellipseGeometry._semiMinorAxis <= 0.0) {
      return;
    }
    var height = ellipseGeometry._height;
    var extrudedHeight = ellipseGeometry._extrudedHeight;
    var extrude = !Math$1.CesiumMath.equalsEpsilon(height, extrudedHeight, 0, Math$1.CesiumMath.EPSILON2);
    ellipseGeometry._center = ellipseGeometry._ellipsoid.scaleToGeodeticSurface(ellipseGeometry._center, ellipseGeometry._center);
    var options = {
      center: ellipseGeometry._center,
      semiMajorAxis: ellipseGeometry._semiMajorAxis,
      semiMinorAxis: ellipseGeometry._semiMinorAxis,
      ellipsoid: ellipseGeometry._ellipsoid,
      rotation: ellipseGeometry._rotation,
      height: height,
      granularity: ellipseGeometry._granularity,
      numberOfVerticalLines: ellipseGeometry._numberOfVerticalLines
    };
    var geometry;
    if (extrude) {
      options.extrudedHeight = extrudedHeight;
      options.offsetAttribute = ellipseGeometry._offsetAttribute;
      geometry = computeExtrudedEllipse(options);
    } else {
      geometry = computeEllipse(options);
      if (defaultValue.defined(ellipseGeometry._offsetAttribute)) {
        var length = geometry.attributes.position.values.length;
        var offsetValue = ellipseGeometry._offsetAttribute === GeometryOffsetAttribute.GeometryOffsetAttribute.NONE ? 0 : 1;
        var applyOffset = new Uint8Array(length / 3).fill(offsetValue);
        geometry.attributes.applyOffset = new GeometryAttribute.GeometryAttribute({
          componentDatatype: ComponentDatatype.ComponentDatatype.UNSIGNED_BYTE,
          componentsPerAttribute: 1,
          values: applyOffset
        });
      }
    }
    return new GeometryAttribute.Geometry({
      attributes: geometry.attributes,
      indices: geometry.indices,
      primitiveType: GeometryAttribute.PrimitiveType.LINES,
      boundingSphere: geometry.boundingSphere,
      offsetAttribute: ellipseGeometry._offsetAttribute
    });
  };
  exports.EllipseOutlineGeometry = EllipseOutlineGeometry;
});