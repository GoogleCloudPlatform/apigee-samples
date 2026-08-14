// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"golang.org/x/oauth2/google"
)

var (
	// Global cache for analytics data
	analyticsCache      []byte
	analyticsCacheMutex sync.RWMutex

	// SSE Broker
	clients      = make(map[chan []byte]bool)
	clientsMutex sync.Mutex
)

// Helper function to broadcast data to all connected SSE clients
func broadcast(data []byte) {
	clientsMutex.Lock()
	defer clientsMutex.Unlock()
	for client := range clients {
		// Send data without blocking
		select {
		case client <- data:
		default:
			// If client channel is full, we could drop them, but let's just skip
		}
	}
}

// Helper function to handle JSON responses
func jsonResponse(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if data != nil {
		json.NewEncoder(w).Encode(data)
	}
}

// withCORS middleware adds CORS headers for permissive access
func withCORS(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}

		next(w, r)
	}
}

func getGCPClient(ctx context.Context) (*http.Client, error) {
	client, err := google.DefaultClient(ctx, "https://www.googleapis.com/auth/cloud-platform")
	if err != nil {
		return nil, err
	}
	return client, nil
}

func doApigeeRequest(ctx context.Context, method, url string, body interface{}, target interface{}) error {
	client, err := getGCPClient(ctx)
	if err != nil {
		return err
	}

	var reqBody io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		reqBody = bytes.NewReader(b)
	}

	req, err := http.NewRequest(method, url, reqBody)
	if err != nil {
		return err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		respBytes, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("apigee API error (%d): %s", resp.StatusCode, string(respBytes))
	}

	if target != nil && resp.StatusCode != http.StatusNoContent {
		return json.NewDecoder(resp.Body).Decode(target)
	}
	return nil
}

func fetchAnalyticsForEmail(ctx context.Context, projectId, env, escapedTimeRange, email string) (map[string]interface{}, error) {
	escapedFilter := strings.Replace(url.QueryEscape(fmt.Sprintf("(developer_email eq '%s')", email)), "+", "%20", -1)

	var appStats []interface{}
	var productStats []interface{}
	var modelStats []interface{}

	// 1. Stats by developer_app
	appStatsUrl := fmt.Sprintf("https://apigee.googleapis.com/v1/organizations/%s/environments/%s/stats/developer_app?select=sum(message_count),sum(dc_prompt_token_count_v2),sum(dc_candidates_token_count_v2),avg(dc_time_to_first_token_v2)&timeUnit=day&timeRange=%s&filter=%s",
		projectId, env, escapedTimeRange, escapedFilter)
	var appStatsResp map[string]interface{}
	if err := doApigeeRequest(ctx, "GET", appStatsUrl, nil, &appStatsResp); err == nil {
		delete(appStatsResp, "metaData")
		appStats = append(appStats, appStatsResp)
	}

	// 2. Stats by api_product
	prodStatsUrl := fmt.Sprintf("https://apigee.googleapis.com/v1/organizations/%s/environments/%s/stats/api_product?select=sum(message_count),sum(dc_prompt_token_count_v2),sum(dc_candidates_token_count_v2),avg(dc_time_to_first_token_v2)&timeUnit=day&timeRange=%s&filter=%s",
		projectId, env, escapedTimeRange, escapedFilter)
	var prodStatsResp map[string]interface{}
	if err := doApigeeRequest(ctx, "GET", prodStatsUrl, nil, &prodStatsResp); err == nil {
		delete(prodStatsResp, "metaData")
		productStats = append(productStats, prodStatsResp)
	}

	// 3. Stats by dc_model_v2
	modelStatsUrl := fmt.Sprintf("https://apigee.googleapis.com/v1/organizations/%s/environments/%s/stats/dc_model_v2?select=sum(message_count),sum(dc_prompt_token_count_v2),sum(dc_candidates_token_count_v2),avg(dc_time_to_first_token_v2)&timeUnit=day&timeRange=%s&filter=%s",
		projectId, env, escapedTimeRange, escapedFilter)
	var modelStatsResp map[string]interface{}
	if err := doApigeeRequest(ctx, "GET", modelStatsUrl, nil, &modelStatsResp); err == nil {
		delete(modelStatsResp, "metaData")
		modelStats = append(modelStats, modelStatsResp)
	}

	return map[string]interface{}{
		"app":     appStats,
		"product": productStats,
		"model":   modelStats,
	}, nil
}

func refreshAnalyticsData(projectId string) error {
	ctx := context.Background()

	// Compute timeRange (last 3 months)
	now := time.Now().UTC()
	threeMonthsAgo := now.AddDate(0, -3, 0)
	timeRange := fmt.Sprintf("%02d/%02d/%04d %02d:%02d~%02d/%02d/%04d %02d:%02d",
		threeMonthsAgo.Month(), threeMonthsAgo.Day(), threeMonthsAgo.Year(), threeMonthsAgo.Hour(), threeMonthsAgo.Minute(),
		now.Month(), now.Day(), now.Year(), now.Hour(), now.Minute())
	escapedTimeRange := strings.Replace(url.QueryEscape(timeRange), "+", "%20", -1)

	// Get all environments for this org
	envUrl := fmt.Sprintf("https://apigee.googleapis.com/v1/organizations/%s/environments", projectId)
	var envs []string
	if err := doApigeeRequest(ctx, "GET", envUrl, nil, &envs); err != nil {
		log.Printf("failed to get environments for org %s: %v", projectId, err)
	}

	// Determine the list of emails to query
	var emailsToQuery []string
	devsUrl := fmt.Sprintf("https://apigee.googleapis.com/v1/organizations/%s/developers", projectId)
	var devsResp struct {
		Developer []struct {
			Email string `json:"email"`
		} `json:"developer"`
	}
	if err := doApigeeRequest(ctx, "GET", devsUrl, nil, &devsResp); err != nil {
		log.Printf("failed to get developers for org $s, %v", projectId, err)
	}
	for _, d := range devsResp.Developer {
		emailsToQuery = append(emailsToQuery, d.Email)
	}

	result := make(map[string]interface{})

	for _, userEmail := range emailsToQuery {
		userStats := map[string][]interface{}{
			"app":     {},
			"product": {},
			"model":   {},
		}

		for _, env := range envs {
			stats, err := fetchAnalyticsForEmail(ctx, projectId, env, escapedTimeRange, userEmail)
			if err != nil {
				continue
			}

			if apps, ok := stats["app"].([]interface{}); ok {
				userStats["app"] = append(userStats["app"], apps...)
			}
			if prods, ok := stats["product"].([]interface{}); ok {
				userStats["product"] = append(userStats["product"], prods...)
			}
			if mods, ok := stats["model"].([]interface{}); ok {
				userStats["model"] = append(userStats["model"], mods...)
			}
		}
		result[userEmail] = userStats
	}

	newCache, err := json.Marshal(result)
	if err != nil {
		return fmt.Errorf("failed to marshal cache: %v", err)
	}

	analyticsCacheMutex.Lock()
	changed := !bytes.Equal(analyticsCache, newCache)
	if changed {
		analyticsCache = newCache
	}
	analyticsCacheMutex.Unlock()

	if changed {
		log.Println("Data changed, broadcasting to clients...")
		broadcast(newCache)
	} else {
		log.Println("Data unchanged, skip broadcast.")
	}

	return nil
}

func userAnalyticsHandler(w http.ResponseWriter, r *http.Request) {
	projectId := r.PathValue("projectId")
	if projectId == "" {
		projectId = os.Getenv("GOOGLE_CLOUD_PROJECT")
	}

	if r.Method != http.MethodGet {
		jsonResponse(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	// Always trigger a refresh when explicitly called
	go func() {
		log.Println("Manual cache refresh triggered")
		if err := refreshAnalyticsData(projectId); err != nil {
			log.Printf("Error refreshing analytics: %v", err)
		}
	}()

	// Immediately return whatever is in cache
	analyticsCacheMutex.RLock()
	cachedData := analyticsCache
	analyticsCacheMutex.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if cachedData != nil {
		w.Write(cachedData)
	} else {
		w.Write([]byte(`{}`))
	}
}

func configHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonResponse(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	projectId := os.Getenv("GOOGLE_CLOUD_PROJECT")
	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"googleCloudProject": projectId,
	})
}

// SSE handler to push analytics to the client
func sseHandler(w http.ResponseWriter, r *http.Request) {
	// Set headers for SSE
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")

	// Create a channel for this specific client
	clientChan := make(chan []byte, 1)

	clientsMutex.Lock()
	clients[clientChan] = true
	clientsMutex.Unlock()

	defer func() {
		clientsMutex.Lock()
		delete(clients, clientChan)
		clientsMutex.Unlock()
		close(clientChan)
	}()

	// Push current cache immediately if available
	analyticsCacheMutex.RLock()
	if analyticsCache != nil {
		w.Write([]byte("data: "))
		w.Write(analyticsCache)
		w.Write([]byte("\n\n"))
		if f, ok := w.(http.Flusher); ok {
			f.Flush()
		}
	}
	analyticsCacheMutex.RUnlock()

	// Wait for updates or connection close
	notify := r.Context().Done()
	for {
		select {
		case <-notify:
			return
		case data := <-clientChan:
			w.Write([]byte("data: "))
			w.Write(data)
			w.Write([]byte("\n\n"))
			if f, ok := w.(http.Flusher); ok {
				f.Flush()
			}
		}
	}
}

// --- MCP and Business Data Types ---

type MCPRequest struct {
	JSONRPC string          `json:"jsonrpc"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params"`
	ID      interface{}     `json:"id"`
}

type MCPResponse struct {
	JSONRPC string      `json:"jsonrpc"`
	Result  interface{} `json:"result,omitempty"`
	Error   interface{} `json:"error,omitempty"`
	ID      interface{} `json:"id"`
}

type CallToolRequest struct {
	Name      string          `json:"name"`
	Arguments json.RawMessage `json:"arguments"`
}

type Customer struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
}

type Address struct {
	ID         string `json:"id"`
	CustomerID string `json:"customer_id"`
	Street     string `json:"street"`
	City       string `json:"city"`
	State      string `json:"state"`
	Zip        string `json:"zip"`
}

type Order struct {
	ID         string    `json:"id"`
	CustomerID string    `json:"customer_id"`
	Amount     float64   `json:"amount"`
	Status     string    `json:"status"` // pending, shipped, delivered, cancelled
	CreatedAt  time.Time `json:"created_at"`
}

type Ticket struct {
	ID         string    `json:"id"`
	CustomerID string    `json:"customer_id"`
	Subject    string    `json:"subject"`
	Status     string    `json:"status"` // open, in_progress, resolved, closed
	CreatedAt  time.Time `json:"created_at"`
}

type Product struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Category    string  `json:"category"`
	Price       float64 `json:"price"`
	Stock       int     `json:"stock"`
}

var (
	bizDataMutex sync.RWMutex
	customers    = []Customer{
		{ID: "cust_1", Name: "Alice Johnson", Email: "alice@example.com"},
		{ID: "cust_2", Name: "Bob Smith", Email: "bob@example.com"},
		{ID: "cust_3", Name: "Charlie Brown", Email: "charlie@example.com"},
	}
	addresses = []Address{
		{ID: "addr_1", CustomerID: "cust_1", Street: "123 Maple St", City: "Springfield", State: "IL", Zip: "62704"},
		{ID: "addr_2", CustomerID: "cust_2", Street: "456 Oak Ave", City: "Metropolis", State: "NY", Zip: "10001"},
		{ID: "addr_3", CustomerID: "cust_3", Street: "789 Pine Ln", City: "Gotham", State: "NJ", Zip: "07001"},
	}
	orders = []Order{
		{ID: "ord_1", CustomerID: "cust_1", Amount: 125.50, Status: "shipped", CreatedAt: time.Now().Add(-48 * time.Hour)},
		{ID: "ord_2", CustomerID: "cust_2", Amount: 50.00, Status: "pending", CreatedAt: time.Now().Add(-2 * time.Hour)},
		{ID: "ord_3", CustomerID: "cust_1", Amount: 210.00, Status: "delivered", CreatedAt: time.Now().Add(-120 * time.Hour)},
	}
	tickets = []Ticket{
		{ID: "tkt_1", CustomerID: "cust_1", Subject: "Package not received", Status: "open", CreatedAt: time.Now().Add(-24 * time.Hour)},
		{ID: "tkt_2", CustomerID: "cust_3", Subject: "Login issue", Status: "resolved", CreatedAt: time.Now().Add(-72 * time.Hour)},
	}
	products = []Product{
		{ID: "prod_1", Name: "Wireless Mouse", Description: "Ergonomic 2.4GHz wireless mouse", Category: "Electronics", Price: 29.99, Stock: 150},
		{ID: "prod_2", Name: "Mechanical Keyboard", Description: "RGB backlit mechanical keyboard", Category: "Electronics", Price: 89.99, Stock: 75},
		{ID: "prod_3", Name: "Desk Lamp", Description: "LED desk lamp with adjustable brightness", Category: "Office", Price: 45.00, Stock: 200},
		{ID: "prod_4", Name: "USB-C Hub", Description: "7-in-1 USB-C adapter with HDMI and Power Delivery", Category: "Electronics", Price: 59.99, Stock: 120},
		{ID: "prod_5", Name: "Notebook", Description: "Premium A5 ruled notebook", Category: "Stationery", Price: 12.50, Stock: 500},
	}
)

func productsHandler(w http.ResponseWriter, r *http.Request) {
	bizDataMutex.Lock()
	defer bizDataMutex.Unlock()

	switch r.Method {
	case http.MethodGet:
		id := r.PathValue("id")
		if id != "" {
			for _, p := range products {
				if p.ID == id {
					jsonResponse(w, http.StatusOK, p)
					return
				}
			}
			jsonResponse(w, http.StatusNotFound, map[string]string{"error": "product not found"})
			return
		}

		// Search/List
		q := r.URL.Query().Get("q")
		cat := r.URL.Query().Get("category")
		var filtered []Product
		for _, p := range products {
			match := true
			if cat != "" && !strings.EqualFold(p.Category, cat) {
				match = false
			}
			if q != "" && !strings.Contains(strings.ToLower(p.Name), strings.ToLower(q)) && !strings.Contains(strings.ToLower(p.Description), strings.ToLower(q)) {
				match = false
			}
			if match {
				filtered = append(filtered, p)
			}
		}
		jsonResponse(w, http.StatusOK, filtered)

	case http.MethodPost:
		var p Product
		if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
			jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "invalid JSON"})
			return
		}
		if p.ID == "" {
			p.ID = fmt.Sprintf("prod_%d", len(products)+1)
		}
		products = append(products, p)
		jsonResponse(w, http.StatusCreated, p)

	case http.MethodPut:
		id := r.PathValue("id")
		if id == "" {
			jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "ID required for update"})
			return
		}
		var updated Product
		if err := json.NewDecoder(r.Body).Decode(&updated); err != nil {
			jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "invalid JSON"})
			return
		}
		for i, p := range products {
			if p.ID == id {
				updated.ID = id // Ensure ID remains same
				products[i] = updated
				jsonResponse(w, http.StatusOK, updated)
				return
			}
		}
		jsonResponse(w, http.StatusNotFound, map[string]string{"error": "product not found"})

	case http.MethodDelete:
		id := r.PathValue("id")
		for i, p := range products {
			if p.ID == id {
				products = append(products[:i], products[i+1:]...)
				jsonResponse(w, http.StatusNoContent, nil)
				return
			}
		}
		jsonResponse(w, http.StatusNotFound, map[string]string{"error": "product not found"})

	default:
		jsonResponse(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
	}
}

func mcpHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonResponse(w, http.StatusMethodNotAllowed, map[string]string{"error": "only POST allowed"})
		return
	}

	var req MCPRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "invalid JSON"})
		return
	}

	var result interface{}
	var err error

	switch req.Method {
	case "initialize":
		result = map[string]interface{}{
			"protocolVersion": "2024-11-05",
			"capabilities": map[string]interface{}{
				"tools": map[string]interface{}{},
			},
			"serverInfo": map[string]string{
				"name":    "Business Operations Server",
				"version": "1.0.0",
			},
		}
	case "tools/list":
		result = map[string]interface{}{
			"tools": []interface{}{
				map[string]interface{}{
					"name":        "list_customers",
					"description": "List all customers",
					"inputSchema": map[string]interface{}{
						"type":       "object",
						"properties": map[string]interface{}{},
					},
				},
				map[string]interface{}{
					"name":        "get_customer",
					"description": "Get customer details by ID",
					"inputSchema": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"id": map[string]interface{}{"type": "string"},
						},
						"required": []string{"id"},
					},
				},
				map[string]interface{}{
					"name":        "update_customer_address",
					"description": "Update a customer's address",
					"inputSchema": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"customer_id": map[string]interface{}{"type": "string"},
							"street":      map[string]interface{}{"type": "string"},
							"city":        map[string]interface{}{"type": "string"},
							"state":       map[string]interface{}{"type": "string"},
							"zip":         map[string]interface{}{"type": "string"},
						},
						"required": []string{"customer_id"},
					},
				},
				map[string]interface{}{
					"name":        "list_orders",
					"description": "List orders, optionally filtered by customer ID",
					"inputSchema": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"customer_id": map[string]interface{}{"type": "string"},
						},
					},
				},
				map[string]interface{}{
					"name":        "update_order_status",
					"description": "Update the status of an order",
					"inputSchema": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"order_id": map[string]interface{}{"type": "string"},
							"status":   map[string]interface{}{"type": "string", "enum": []string{"pending", "shipped", "delivered", "cancelled"}},
						},
						"required": []string{"order_id", "status"},
					},
				},
				map[string]interface{}{
					"name":        "create_ticket",
					"description": "Create a new customer support ticket",
					"inputSchema": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"customer_id": map[string]interface{}{"type": "string"},
							"subject":     map[string]interface{}{"type": "string"},
						},
						"required": []string{"customer_id", "subject"},
					},
				},
				map[string]interface{}{
					"name":        "list_tickets",
					"description": "List customer support tickets",
					"inputSchema": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"customer_id": map[string]interface{}{"type": "string"},
						},
					},
				},
				map[string]interface{}{
					"name":        "update_ticket_status",
					"description": "Update the status of a support ticket",
					"inputSchema": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"ticket_id": map[string]interface{}{"type": "string"},
							"status":    map[string]interface{}{"type": "string", "enum": []string{"open", "in_progress", "resolved", "closed"}},
						},
						"required": []string{"ticket_id", "status"},
					},
				},
			},
		}
	case "tools/call":
		var callReq CallToolRequest
		if err := json.Unmarshal(req.Params, &callReq); err != nil {
			jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "invalid params"})
			return
		}
		result, err = handleToolCall(callReq.Name, callReq.Arguments)
	default:
		jsonResponse(w, http.StatusNotFound, map[string]string{"error": "method not found"})
		return
	}

	if err != nil {
		jsonResponse(w, http.StatusOK, MCPResponse{
			JSONRPC: "2.0",
			Error:   map[string]interface{}{"code": -32603, "message": err.Error()},
			ID:      req.ID,
		})
		return
	}

	jsonResponse(w, http.StatusOK, MCPResponse{
		JSONRPC: "2.0",
		Result:  result,
		ID:      req.ID,
	})
}

func handleToolCall(name string, arguments json.RawMessage) (interface{}, error) {
	bizDataMutex.Lock()
	defer bizDataMutex.Unlock()

	var args map[string]interface{}
	json.Unmarshal(arguments, &args)

	switch name {
	case "list_customers":
		return mcpTextResponse(customers), nil

	case "get_customer":
		id, _ := args["id"].(string)
		for _, c := range customers {
			if c.ID == id {
				// Find address too
				var addr Address
				for _, a := range addresses {
					if a.CustomerID == id {
						addr = a
						break
					}
				}
				return mcpTextResponse(map[string]interface{}{
					"customer": c,
					"address":  addr,
				}), nil
			}
		}
		return nil, fmt.Errorf("customer not found: %s", id)

	case "update_customer_address":
		customerID, _ := args["customer_id"].(string)
		for i, a := range addresses {
			if a.CustomerID == customerID {
				if v, ok := args["street"].(string); ok {
					addresses[i].Street = v
				}
				if v, ok := args["city"].(string); ok {
					addresses[i].City = v
				}
				if v, ok := args["state"].(string); ok {
					addresses[i].State = v
				}
				if v, ok := args["zip"].(string); ok {
					addresses[i].Zip = v
				}
				return mcpTextResponse(addresses[i]), nil
			}
		}
		// If address doesn't exist, create it
		newAddr := Address{
			ID:         fmt.Sprintf("addr_%d", len(addresses)+1),
			CustomerID: customerID,
			Street:     args["street"].(string),
			City:       args["city"].(string),
			State:      args["state"].(string),
			Zip:        args["zip"].(string),
		}
		addresses = append(addresses, newAddr)
		return mcpTextResponse(newAddr), nil

	case "list_orders":
		customerID, _ := args["customer_id"].(string)
		var filtered []Order
		for _, o := range orders {
			if customerID == "" || o.CustomerID == customerID {
				filtered = append(filtered, o)
			}
		}
		return mcpTextResponse(filtered), nil

	case "update_order_status":
		orderID, _ := args["order_id"].(string)
		status, _ := args["status"].(string)
		for i, o := range orders {
			if o.ID == orderID {
				orders[i].Status = status
				return mcpTextResponse(orders[i]), nil
			}
		}
		return nil, fmt.Errorf("order not found: %s", orderID)

	case "create_ticket":
		customerID, _ := args["customer_id"].(string)
		subject, _ := args["subject"].(string)
		newTicket := Ticket{
			ID:         fmt.Sprintf("tkt_%d", len(tickets)+1),
			CustomerID: customerID,
			Subject:    subject,
			Status:     "open",
			CreatedAt:  time.Now(),
		}
		tickets = append(tickets, newTicket)
		return mcpTextResponse(newTicket), nil

	case "list_tickets":
		customerID, _ := args["customer_id"].(string)
		var filtered []Ticket
		for _, t := range tickets {
			if customerID == "" || t.CustomerID == customerID {
				filtered = append(filtered, t)
			}
		}
		return mcpTextResponse(filtered), nil

	case "update_ticket_status":
		ticketID, _ := args["ticket_id"].(string)
		status, _ := args["status"].(string)
		for i, t := range tickets {
			if t.ID == ticketID {
				tickets[i].Status = status
				return mcpTextResponse(tickets[i]), nil
			}
		}
		return nil, fmt.Errorf("ticket not found: %s", ticketID)
	}

	return nil, fmt.Errorf("unknown tool: %s", name)
}

func mcpTextResponse(data interface{}) interface{} {
	b, _ := json.MarshalIndent(data, "", "  ")
	return map[string]interface{}{
		"content": []interface{}{
			map[string]interface{}{
				"type": "text",
				"text": string(b),
			},
		},
	}
}

func main() {
	mux := http.NewServeMux()

	landingFs := http.FileServer(http.Dir("public"))
	mux.Handle("/", landingFs)

	mux.HandleFunc("/api/projects/{projectId}/users/analytics/stream", withCORS(sseHandler))
	mux.HandleFunc("/api/projects/{projectId}/users/{email}/analytics", withCORS(userAnalyticsHandler))
	mux.HandleFunc("/api/projects/{projectId}/users/analytics", withCORS(userAnalyticsHandler))
	mux.HandleFunc("/api/config", withCORS(configHandler))

	// serve OpenAPI spec
	mux.HandleFunc("/openapi", withCORS(func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "public/openapi-viewer.html")
	}))
	mux.HandleFunc("/openapi.yaml", withCORS(func(w http.ResponseWriter, r *http.Request) {
		content, err := os.ReadFile("openapi.yaml")
		if err != nil {
			http.Error(w, "Could not read OpenAPI spec", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.Header().Set("Content-Disposition", "inline")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
		w.Header().Set("Pragma", "no-cache")
		w.Header().Set("Expires", "0")
		w.Write(content)
	}))

	// mock business services
	mux.HandleFunc("/products", withCORS(productsHandler))
	mux.HandleFunc("/products/{id}", withCORS(productsHandler))
	mux.HandleFunc("/mcp", withCORS(mcpHandler))

	// Initial cache load for the default project (if set)
	projectId := os.Getenv("GOOGLE_CLOUD_PROJECT")
	if projectId != "" {
		log.Printf("Starting initial background cache refresh for project: %s", projectId)
		go func() {
			if err := refreshAnalyticsData(projectId); err != nil {
				log.Printf("Initial cache refresh failed: %v", err)
			}
		}()
	}

	log.Println("Server listening on :8080")
	if err := http.ListenAndServe(":8080", mux); err != nil {
		log.Fatal(err)
	}
}
