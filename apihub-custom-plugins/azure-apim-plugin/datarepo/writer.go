package datarepo

import (
	"context"
	"errors"
	"log"
	"time"

	"cloud.google.com/go/spanner"
	"google.golang.org/api/iterator"
	"google.golang.org/grpc/codes"
)

var (
	// ErrDuplicateResource indicates that a resource already exists.
	ErrDuplicateResource = errors.New("resource already exists")
	// ErrResourceNotFound indicates that a resource was not found.
	ErrResourceNotFound = errors.New("resource not found")
)

const (
	deleteOnRampPluginInstanceActionsQuery = `
DELETE FROM OnrampPluginInstanceActions op
WHERE op.PluginID = @pluginID AND op.PluginInstanceID = @pluginInstanceID`
)

// Audit adds the created and updated time to the row.
func Audit(row map[string]any, insert bool) map[string]any {
	if insert {
		row[ColumnCreationTime] = time.Now()
		row[ColumnLastModifiedTime] = time.Now()
		return row
	}
	row[ColumnLastModifiedTime] = time.Now()
	return row

}

// Writer is used to write data to the data repo.
type Writer struct {
	spClient *spanner.Client
}

// NewWriter is used to create a new writer.
func NewWriter(spClient *spanner.Client) *Writer {
	return &Writer{spClient: spClient}
}

// InsertOnRampPluginInstanceActions is used to insert OnRampPluginInstance in db.
// Note, this method assumes that every plugin instance has at least one action. The same will be
// validated at the validation layer.
// This also assumes that actions are unique within a plugin instance.
func (w *Writer) InsertOnRampPluginInstanceActions(ctx context.Context, actions []*OnRampPluginInstanceAction) (time.Time, error) {
	var m []*spanner.Mutation
	for _, action := range actions {
		m = append(m, spanner.InsertMap(TableOnRampPluginInstanceActions, Audit(onRampPluginInstanceActionRow(action), true)))
	}
	commitTime, err := w.spClient.Apply(ctx, m)
	if spanner.ErrCode(err) == codes.AlreadyExists {
		log.Printf("Error: OnRampPluginInstanceAction already exists: %v", err)
		return time.Time{}, ErrDuplicateResource
	}
	return commitTime, err
}

// UpdateOnRampPluginInstanceAction is used to update an OnRampPluginInstanceAction in db.
// This will update the metadata of the action.
func (w *Writer) UpdateOnRampPluginInstanceAction(ctx context.Context, action *OnRampPluginInstanceAction) (time.Time, error) {
	m := []*spanner.Mutation{spanner.UpdateMap(TableOnRampPluginInstanceActions, Audit(onRampPluginInstanceActionRow(action), false))}
	commitTime, err := w.spClient.Apply(ctx, m)
	if spanner.ErrCode(err) == codes.NotFound {
		log.Printf("Error: OnRampPluginInstanceAction not found: %v", err)
		return time.Time{}, ErrResourceNotFound
	}
	return commitTime, err
}

// DeleteOnRampPluginInstanceActions deletes an OnRampPluginInstanceActions given a plugin and plugin instance id.
// It doesn't throw an error if the onRampPluginInstance with the given ids doesn't exist.
func (w *Writer) DeleteOnRampPluginInstanceActions(ctx context.Context, pluginID, pluginInstanceID string) error {
	_, err := w.spClient.ReadWriteTransaction(ctx, func(ctx context.Context, txn *spanner.ReadWriteTransaction) error {
		iter := txn.Query(ctx, spanner.Statement{
			SQL: deleteOnRampPluginInstanceActionsQuery,
			Params: map[string]any{
				"pluginID":         pluginID,
				"pluginInstanceID": pluginInstanceID,
			},
		})
		defer iter.Stop()
		_, err := iter.Next()
		if err == iterator.Done {
			return nil
		}
		return err
	})
	return err
}

func onRampPluginInstanceActionRow(o *OnRampPluginInstanceAction) map[string]any {
	row := make(map[string]any)
	row[ColumnPluginInstanceID] = o.PluginInstanceID
	row[ColumnPluginID] = o.PluginID
	row[ColumnActionID] = o.ActionID
	if o.Metadata != (Metadata{}) {
		row[ColumnMetadata] = spanner.NullJSON{Value: o.Metadata, Valid: true}
	}
	return row
}
