// Package datarepo provides the data access layer for the Azure APIM plugin.
package datarepo

import (
	"time"
)

// Metadata represents the Azure plugin metadata structure.
type Metadata struct {
	TenantID             string    `json:"azureTenantId"`
	SubscriptionID       string    `json:"azureSubscriptionId"`
	ClientID             string    `json:"clientId"`
	ClientSecretKey      string    `json:"clientSecret"`
	GoogleServiceAccount string    `json:"googleServiceAccount"`
	LastSyncTime         time.Time `json:"lastSyncTime"`
	SyncStatus           string    `json:"syncStatus"`
	IntegrationLocation  string    `json:"integrationLocation"`
	TriggerID            string    `json:"triggerId"`
	IntegrationVersionID string    `json:"integrationVersionId"`
	IntegrationName      string    `json:"integrationName"`
}

// OnRampPluginInstanceAction represents the complete plugin action structure.
type OnRampPluginInstanceAction struct {
	PluginID         string
	PluginInstanceID string
	ActionID         string
	Metadata         Metadata `json:"metadata"`
	CreationTime     time.Time
	LastModifiedTime time.Time
}

func onRampPluginInstanceActionColumns() []string {
	return []string{
		ColumnPluginID,
		ColumnPluginInstanceID,
		ColumnActionID,
		ColumnMetadata,
		ColumnCreationTime,
		ColumnLastModifiedTime,
	}
}
