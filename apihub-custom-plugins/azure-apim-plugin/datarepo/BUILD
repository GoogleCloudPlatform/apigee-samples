# This load path assumes you are using bzlmod or have rules_go configured
# in your workspace.
load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

# Defines the Go library for the `datarepo` package.
go_library(
    name = "datarepo",
    srcs = [
        "constants.go",
        "reader.go",
        "schema.go",
        "writer.go",
    ],
    # IMPORTANT: You must provide the correct Go import path for your project.
    importpath = "github.com/your_org/apihub-custom-plugins/azure-apim-plugin/datarepo",
    visibility = ["//visibility:public"],
    deps = [
        # Corresponds to cloud.google.com/go/spanner
        "@com_google_cloud_go_spanner//:spanner",
        # Corresponds to google.golang.org/api/iterator
        "@org_golang_google_api//iterator",
        # Corresponds to google.golang.org/grpc/codes
        "@org_golang_google_grpc//codes",
    ],
)

# Defines the test for the `datarepo` library.
go_test(
    name = "datarepo_test",
    srcs = [
        "reader_test.go",
        "writer_test.go",
    ],
    # 'embed' links the test to the library being tested.
    embed = [":datarepo"],
    deps = [
        # Corresponds to github.com/google/go-cmp/cmp
        "@com_github_google_go_cmp//cmp",
        # Corresponds to github.com/google/go-cmp/cmp/cmpopts
        "@com_github_google_go_cmp//cmp/cmpopts",
        # Corresponds to cloud.google.com/go/spanner
        "@com_google_cloud_go_spanner//:spanner",
        # Corresponds to google.golang.org/api/iterator
        "@org_golang_google_api//iterator",
    ],
)