package datarepo

// Cloud Spanner table and column constants.
const (
   TableOnRampPluginInstanceActions = "OnRampPluginInstanceActions"


   // Column names.
   ColumnPluginID         = "PluginID"
   ColumnPluginInstanceID = "PluginInstanceID"
   ColumnActionID         = "ActionID"
   ColumnMetadata         = "Metadata"
   ColumnCreationTime     = "CreationTime"
   ColumnLastModifiedTime = "LastModifiedTime"
)


// PluginID represents pluginID value.
type PluginID string


// Plugin ID constants.
const (
   // PluginIDUnspecified is used when the plugin is unspecified.
   PluginIDUnspecified PluginID = "unspecified"
   // PluginIDAzure is used when the plugin is Azure.
   PluginIDAzure PluginID = "custom-azure"
)
