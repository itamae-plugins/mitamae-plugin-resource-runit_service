# mitamae-plugin-resource-runit\_service

MItamae plugin to reproduce the behavior of https://github.com/chef-cookbooks/runit ~v1.7.8~ v1.5.8

## Usage

See https://github.com/itamae-kitchen/mitamae/blob/v1.5.6/PLUGINS.md.

Put this repository as `./plugins/mitamae-plugin-resource-runit_service`,
and execute `mitamae local` where you can find `./plugins` directory.

### Example

```rb
runit_service 'app' do
  log_size 50_000_000
  log_num  4
end
```

## License & Authors

- Author:: Adam Jacob [adam@chef.io](mailto:adam@chef.io)
- Author:: Joshua Timberman [joshua@chef.io](mailto:joshua@chef.io)
- Author:: Sean OMeara [sean@sean.io](mailto:sean@sean.io)

```text
Copyright:: 2008-2016, Chef Software, Inc

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
