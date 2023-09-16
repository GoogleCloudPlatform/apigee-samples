# How to Contribute

We'd love to accept your patches and contributions to this project. There are
just a few guidelines you need to follow.

## General Guidelines

1. The primary focus of this repo is to provide introductory Apigee samples of low to medium complexity, aimed at developers who are new to Apigee
    - More complex projects may be better suited for the [Apigee DevRel](https://github.com/apigee/devrel) repo
1. Projects in this repo are targeted for [Apigee X](https://cloud.google.com/apigee/docs) and [hybrid](https://cloud.google.com/apigee/docs/hybrid/latest/what-is-hybrid). We do not accept samples for the Apigee Edge platform (these may be found [here](https://github.com/apigee/api-platform-samples))
    - More information about the different versions of Apigee can be found [here](https://cloud.google.com/apigee/docs/api-platform/get-started/compare-apigee-products)
1. Projects accepted to this repository should be considered a recommended best practice by Apigee's product management, field engineers, customers and community
1. For large pull requests (e.g. rewrites of large portions or entire projects), please first propose the changes via a new GitHub [issue](https://github.com/GoogleCloudPlatform/apigee-samples/issues/new/choose) and discuss with the community before submitting a PR

## Quickstart

1. [Fork](https://docs.github.com/en/github/getting-started-with-github/fork-a-repo)
 the repository and make your contribution. Please don't make changes to
 multiple projects in the same pull request
    - Consult
[GitHub Help](https://help.github.com/articles/about-pull-requests/) for more
information on using pull requests
1. Ensure the pull request checks listed below all pass
1. Submit your PR, and we will perform a code review
1. Once any issues are resolved, your change will be merged!

## <a name="pull-request-checks"></a>Pull Request Checks

- Submitter has signed a [Contributor License Agreement](#cla) (see below)
- [Apache 2.0 License](https://opensource.google/docs/releasing/preparing/#license-file) is present (you can [automate](https://github.com/google/addlicense)
 this)
- Sample is listed in the main [README](./README.md#samples)
- [Mega Linter](https://megalinter.github.io) checks pass
- [apigeelint](https://github.com/apigee/apigeelint) checks pass
- Commit messages follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
  standard

## <a name="cla"></a>Contributor License Agreement

Contributions to this project must be accompanied by a Contributor License
Agreement. You (or your employer) retain the copyright to your contribution;
this simply gives us permission to use and redistribute your contributions as
part of the project. Head over to <https://cla.developers.google.com/> to see
your current agreements on file or to sign a new one.

You generally only need to submit a CLA once, so if you've already submitted one
(even if it was for a different project), you probably don't need to do it
again.

## Community Guidelines

This project follows
[Google's Open Source Community Guidelines](https://opensource.google.com/conduct/).
