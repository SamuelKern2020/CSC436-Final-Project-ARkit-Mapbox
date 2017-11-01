import ARKit
import SpriteKit
import CoreLocation

@objc public protocol AnnotationManagerDelegate {
    
    @objc optional func node(for annotation: Annotation) -> SCNNode?
    @objc optional func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera)
    
}

public class AnnotationManager: NSObject {
    
    public private(set) var session: ARSession
    public private(set) var sceneView: ARSCNView?
    public private(set) var anchors = [ARAnchor]()
    public private(set) var annotationsByAnchor = [ARAnchor: Annotation]()  //dictionary of Annotations, queryable by anchor
    public private(set) var annotationsByNode = [SCNNode: Annotation]()     //dictionary of Annotations, queryable by Node
    public var delegate: AnnotationManagerDelegate?
    
    public var annotationToMove: Annotation?    // For testing
    public var originLocation: CLLocation?  // a public variable, accessible from other classes, that represents the orgin location and is used to orient additional annotations in respect to the user's current location.
    

    
    public init(session: ARSession) {
        self.session = session
    }
    
    convenience public init(sceneView: ARSCNView) {
        self.init(session: sceneView.session)
        session = sceneView.session
        sceneView.delegate = self
    }
    
    public func addAnnotation(annotation: Annotation) {
        guard let originLocation = originLocation else {
            print("Warning: \(type(of: self)).\(#function) was called without first setting \(type(of: self)).originLocation")
            return
        }
        
        // Create a Mapbox AR anchor anchor at the transformed position
        let anchor = MBARAnchor(originLocation: originLocation, location: annotation.location)
//        print("Created a new MBARAnchor, which looks like this: ")
//        print(anchor)
        
        // Add the anchor to the session
        session.add(anchor: anchor)
        
        // Append the anchor to the anchors array
        anchors.append(anchor)
        
        // Set the annotations anchor to the one just created (now the annotation and anchor are paired)
        annotation.anchor = anchor
        
        // Add the annotation to the annotationsByAnchor dictionary, with the anchor as the key
        annotationsByAnchor[anchor] = annotation
        
    }
    
    public func addAnnotations(annotations: [Annotation]) {
        for annotation in annotations {
            addAnnotation(annotation: annotation)
        }
    }
    
    
    public func testMoveAnnotation(annotation: Annotation, updatedLocation: CLLocation){
       
        //update the annotation's location
        annotation.location = updatedLocation
        
        if let oldAnchor = annotation.anchor {
            annotationsByAnchor.removeValue(forKey: oldAnchor)
            
            // remove anchor from the session
            session.remove(anchor: oldAnchor)
            
            // delete the anchor from the anchors array
            for (index, anchor) in anchors.enumerated() {
                if anchor == oldAnchor {
                    anchors.remove(at: index)
                    break
                }
            }
            
            // create a new MBARAnchor
            guard let originLocation = originLocation else {
                print("Warning: \(type(of: self)).\(#function) was called without first setting \(type(of: self)).originLocation")
                return
            }
            let newAnchor = MBARAnchor(originLocation: originLocation, location: updatedLocation)
            
            // Add the anchor to the session
            session.add(anchor: newAnchor)
            
            // Append the anchor to the anchors array
            anchors.append(newAnchor)
            
            // Set the annotations anchor to the one just created (now the annotation and anchor are paired)
            annotation.anchor = newAnchor
            
            // Add the annotation to the annotationsByAnchor dictionary, with the anchor as the key
            annotationsByAnchor[newAnchor] = annotation

            // Update the annotationToMove in the ViewController
            annotationToMove?.anchor = newAnchor
        }
 
    }

    
    public func removeAllAnnotations() {
        for anchor in anchors {
            session.remove(anchor: anchor)
        }
        
        anchors.removeAll()
        annotationsByAnchor.removeAll()
    }
    
    public func removeAnnotations(annotations: [Annotation]) {
        for annotation in annotations {
            removeAnnotation(annotation: annotation)
        }
    }
    
    public func removeAnnotation(annotation: Annotation) {
        if let anchor = annotation.anchor {
            session.remove(anchor: anchor)
            anchors.remove(at: anchors.index(of: anchor)!)
            annotationsByAnchor.removeValue(forKey: anchor)
        }
    }
    
}

// MARK: - ARSCNViewDelegate

extension AnnotationManager: ARSCNViewDelegate {
    
    public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        delegate?.session?(session, cameraDidChangeTrackingState: camera)
    }
    
    // Gets called when a new anchor is created, but after the addAnnotations() / addAnnocation() functions have completed
    public func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        // node is the newly created node (probaby the center of the sphere?)
        
        // Handle MBARAnchor
        if let anchor = anchor as? MBARAnchor {
            let annotation = annotationsByAnchor[anchor]!
            
            var newNode: SCNNode!
            
            // If the delegate supplied a node then use that, otherwise provide a basic default node
            if let suppliedNode = delegate?.node?(for: annotation) {    // If there is a function called node() in the delegate (in this case ViewController.sift), call THAT function.
                newNode = suppliedNode
               
            } else {
                newNode = createDefaultNode()
            }
            
            // Creates the floating callout image (the star) and adds it as a child to the floating sphere)
            if let calloutImage = annotation.calloutImage {
                let calloutNode = createCalloutNode(with: calloutImage, node: newNode)
                newNode.addChildNode(calloutNode)
            }
            
            node.addChildNode(newNode)  //Attaches the Sphere node and the 2D callout image node (a star) to the newly added node - this DISPLAYS the nodes.
            
            annotationsByNode[newNode] = annotation //Uses the newNode as a key to access the cooresponding annotation in the annotationsByNode dictionary
        }
        
        // TODO: let delegate provide a node for a non-MBARAnchor
    }
    
    // From SAM: Probably could add willUpdate and didUpdate methods here to change the size/visuals of nodes that have already been placed in AR. See documentation here: https://developer.apple.com/documentation/arkit/arscnviewdelegate
    
    
    // MARK: - Utility methods for ARSCNViewDelegate
    
    func createDefaultNode() -> SCNNode {
        let geometry = SCNSphere(radius: 0.2)
        geometry.firstMaterial?.diffuse.contents = UIColor.red
        return SCNNode(geometry: geometry)
    }
    
    // I think this creates the floating star above the sphere...
    func createCalloutNode(with image: UIImage, node: SCNNode) -> SCNNode {
        
        var width: CGFloat = 0.0
        var height: CGFloat = 0.0
        
        if image.size.width >= image.size.height {
            width = image.size.width / image.size.height
            height = 1.0
        } else {
            width = 1.0
            height = image.size.height / image.size.width
        }
        
        let calloutGeometry = SCNPlane(width: width, height: height)
        calloutGeometry.firstMaterial?.diffuse.contents = image
        
        let calloutNode = SCNNode(geometry: calloutGeometry)
        var nodePosition = node.position
        let (min, max) = node.boundingBox
        let nodeHeight = max.y - min.y
        nodePosition.y = nodeHeight + 0.5
        
        calloutNode.position = nodePosition
        
        let constraint = SCNBillboardConstraint()
        constraint.freeAxes = [.Y]
        calloutNode.constraints = [constraint]
        
        return calloutNode
    }
    
}
