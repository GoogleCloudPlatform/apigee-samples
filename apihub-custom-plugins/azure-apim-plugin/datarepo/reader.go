package datarepo

import (
    "context"
    "encoding/json"
    "fmt"
    "log"

    "cloud.google.com/go/spanner"
    "google.golang.org/api/iterator"
    "google.golang.org/grpc/codes"
)

const (
    completeOnRampPluginInstanceQuery = `
SELECT
    *
FROM
    OnrampPluginInstanceActions op
WHERE
    op.PluginID = @pluginID AND op.PluginInstanceID = @pluginInstanceID`
)

// OnRampPluginInstanceActionColumns lists the columns to read for OnRampPluginInstanceActions.
var OnRampPluginInstanceActionColumns = []string{
    ColumnPluginID,
    ColumnPluginInstanceID,
    ColumnActionID,
    ColumnMetadata,
    ColumnCreationTime,
    ColumnLastModifiedTime,
}

// Reader provides methods to read on-ramp plugin instances data from the database.
type Reader struct {
    spClient *spanner.Client
}

// NewReader returns a new instance of Reader.
func NewReader(spClient *spanner.Client) *Reader {
    return &Reader{spClient: spClient}
}

// jsonToT converts a spanner.NullJSON object to a concrete object of type T.
func jsonToT[T any](val spanner.NullJSON) (*T, error) {
    if !val.Valid {
        return nil, nil
    }
    marshalled, err := val.MarshalJSON()
    if err != nil {
        return nil, err
    }
    var data T
    if err := json.Unmarshal(marshalled, &data); err != nil {
        return nil, err
    }
    return &data, nil
}

// jsonData fetches the column value in the form of json and unmarshals it in a concrete object.
func jsonData[T any](row *spanner.Row, colName string) (*T, error) {
    var d spanner.NullJSON
    if err := row.ColumnByName(colName, &d); err != nil {
        return nil, fmt.Errorf("failed to decode column %v: %v", colName, err)
    }

    return jsonToT[T](d)
}

// parseColumnError formats a column parsing error.
func parseColumnError(columnName string, err error) error {
    return fmt.Errorf("failed to parse column %q: %v", columnName, err)
}

// OnRampPluginInstanceActions returns all the on-ramp plugin instance actions for the given plugin id and plugin instance id.
func (r *Reader) OnRampPluginInstanceActions(ctx context.Context, pluginID, pluginInstanceID string) ([]*OnRampPluginInstanceAction, error) {
    iter := r.spClient.Single().Query(ctx, spanner.Statement{
        SQL: completeOnRampPluginInstanceQuery,
        Params: map[string]any{
            "pluginID":         pluginID,
            "pluginInstanceID": pluginInstanceID,
        },
    })
    defer iter.Stop()
    var actions []*OnRampPluginInstanceAction
    for {
        row, err := iter.Next()
        if err == iterator.Done {
            if len(actions) == 0 {
                log.Printf("Error: OnRampPluginInstance not found: %v", err)
                return nil, ErrResourceNotFound
            }
            return actions, nil
        }
        if err != nil {
            return nil, err
        }
        pa, err := parseOnRampPluginInstanceAction(row)
        if err != nil {
            return nil, err
        }
        actions = append(actions, pa)
    }
}

// OnRampPluginInstanceAction returns the on-ramp plugin instance action given the plugin id, plugin instance id and action id.
func (r *Reader) OnRampPluginInstanceAction(ctx context.Context, pluginID, pluginInstanceID, actionID string) (*OnRampPluginInstanceAction, error) {
	row, err := r.spClient.Single().ReadRow(ctx, TableOnRampPluginInstanceActions, spanner.Key{pluginID, pluginInstanceID, actionID}, OnRampPluginInstanceActionColumns)
    if err != nil {
        if spanner.ErrCode(err) == codes.NotFound {
            log.Printf("Error: OnRampPluginInstanceAction not found: %v", err)
            return nil, ErrResourceNotFound
        }
        return nil, err
    }
    return parseOnRampPluginInstanceAction(row)
}

func parseOnRampPluginInstanceAction(row *spanner.Row) (*OnRampPluginInstanceAction, error) {
    p := &OnRampPluginInstanceAction{}
    var err error
    var pluginID string
    if err = row.ColumnByName(ColumnPluginID, &pluginID); err != nil {
        return nil, parseColumnError(ColumnPluginID, err)
    }
    p.PluginID = pluginID
    if err = row.ColumnByName(ColumnPluginInstanceID, &p.PluginInstanceID); err != nil {
        return nil, parseColumnError(ColumnPluginInstanceID, err)
    }
    if err = row.ColumnByName(ColumnActionID, &p.ActionID); err != nil {
        return nil, parseColumnError(ColumnActionID, err)
    }
    metadataPtr, err := jsonData[Metadata](row, ColumnMetadata)
    if err != nil {
        return nil, err
    }
    if metadataPtr != nil {
        p.Metadata = *metadataPtr
    }
    if err = row.ColumnByName(ColumnCreationTime, &p.CreationTime); err != nil {
        return nil, parseColumnError(ColumnCreationTime, err)
    }
    if err = row.ColumnByName(ColumnLastModifiedTime, &p.LastModifiedTime); err != nil {
        return nil, parseColumnError(ColumnLastModifiedTime, err)
    }
    return p, nil
}