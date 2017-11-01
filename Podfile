# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'MapboxARKit' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for MapboxARKit

  target 'MapboxARKitTests' do
    inherit! :search_paths
    # Pods for testing
  end

end

target 'MapboxARKitDemoApp' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for MapboxARKitDemoApp

    # The MapboxARKit pod
    pod 'MapboxARKit', :git => 'https://github.com/mapbox/mapbox-arkit-ios.git'

    # The Turf-swift dependency must be installed manually in the client app until the Turf pod is published on CocoaPods
    pod 'Turf-swift', :git => 'https://github.com/mapbox/turf-swift.git'

end
