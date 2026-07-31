from qgis.processing import alg
from qgis.core import (
    QgsProject, 
    QgsPointXY, 
    QgsSpatialIndex, 
    QgsFeatureRequest,
    QgsProcessing,
    Qgis
)
from qgis.utils import iface

@alg(name="sequential_naming_points", label="Sequential Naming (Points)", group="vector", group_label="Vector")
# Target vector layer input parameter
@alg.input(type=alg.VECTOR_LAYER, name="INPUT_LAYER", label="Target Point Layer", types=[QgsProcessing.TypeVectorPoint])
# Field dropdown bound to the parent layer parameter using the correct QGIS keyword argument
@alg.input(type=alg.FIELD, name="ID_FIELD_NAME", label="Target Field Name (e.g., id)", parentLayerParameterName="INPUT_LAYER")
@alg.input(type=alg.STRING, name="PREFIX", label="User Input Prefix", default="p1ab-1110")
@alg.input(type=alg.POINT, name="START_POINT", label="Click First Point on Map")
@alg.input(type=alg.POINT, name="END_POINT", label="Click Last Point on Map")
@alg.output(type=alg.NUMBER, name="OUTPUT", label="Processed Features Count")
def sequence_points(instance, parameters, context, feedback, inputs):
    """
    Sequentially IDs selected points on the actively highlighted layer based on geographic proximity from start to end.
    """
    # Extract the layer directly from the processing parameter window
    layer = instance.parameterAsVectorLayer(parameters, "INPUT_LAYER", context)
    
    if not layer or layer.type() != layer.VectorLayer:
        feedback.reportError("No active vector layer selected! Highlight your point layer in the Layers Panel.")
        return {"OUTPUT": 0}
        
    if layer.geometryType() != 0: # 0 means Point geometry
        feedback.reportError("The active layer is not a point layer. Please select a point layer.")
        return {"OUTPUT": 0}

    # Extract remaining parameters using instance wrapper context
    field_name = instance.parameterAsString(parameters, "ID_FIELD_NAME", context)
    prefix = instance.parameterAsString(parameters, "PREFIX", context)
    start_pt = instance.parameterAsPoint(parameters, "START_POINT", context, layer.crs())
    end_pt = instance.parameterAsPoint(parameters, "END_POINT", context, layer.crs())
    
    # Verify field existence
    field_idx = layer.fields().indexOf(field_name)
    if field_idx == -1:
        feedback.reportError(f"Field '{field_name}' does not exist in the active layer!")
        return {"OUTPUT": 0}

    # Fetch selected features
    selected_features = list(layer.selectedFeatures())
    if not selected_features:
        feedback.reportError("No features selected! Please select points in your layer first.")
        return {"OUTPUT": 0}

    # Sort features by geographic distance from the start point
    def get_distance(feature):
        geom = feature.geometry()
        if geom.isMultipart():
            point = geom.asMultiPoint() if geom.asMultiPoint() else geom.asPoint()
        else:
            point = geom.asPoint()
        return QgsPointXY(point).distance(QgsPointXY(start_pt))

    selected_features.sort(key=get_distance)

    # Apply sequential naming within an edit block
    layer.startEditing()
    processed_count = 0
    
    try:
        for index, feature in enumerate(selected_features, start=1):
            unique_id = f"{prefix}-{index}"
            layer.changeAttributeValue(feature.id(), field_idx, unique_id)
            processed_count += 1
            
        layer.commitChanges()
        feedback.pushInfo(f"Successfully updated {processed_count} features.")
        
    except Exception as e:
        layer.rollBack()
        feedback.reportError(f"An error occurred during execution: {str(e)}")
        return {"OUTPUT": 0}

    return {"OUTPUT": processed_count}
