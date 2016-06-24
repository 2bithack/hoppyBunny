//
//  GameScene.swift
//  hoppyBunny
//
//  Created by enzo bot on 6/23/16.
//  Copyright (c) 2016 GarbageGames. All rights reserved.
//

import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    enum GameSceneState {
        case Active, GameOver
    }
    var gameState: GameSceneState = .Active
    var hero: SKSpriteNode!
    var scrollLayer: SKNode!
    var obstacleLayer: SKNode!
    var scoreLabel: SKLabelNode!
    var buttonRestart: MSButtonNode!
    var points = 0
    var sinceTouch: CFTimeInterval = 0
    var spawnTimer: CFTimeInterval = 0
    let fixedDelta: CFTimeInterval = 1.0/60.0 //60 fps
    let scrollSpeed: CGFloat = 160
    
    
    
    override func didMoveToView(view: SKView) {
        //load hero
        hero = self.childNodeWithName("//hero") as! SKSpriteNode
        scrollLayer = self.childNodeWithName("scrollLayer")
        physicsWorld.contactDelegate = self
        buttonRestart = self.childNodeWithName("buttonRestart") as! MSButtonNode
        scoreLabel = self.childNodeWithName("scoreLabel") as! SKLabelNode
        
        /* Setup restart button selection handler */
        buttonRestart.selectedHandler = {
            
            /* Grab reference to our SpriteKit view */
            let skView = self.view as SKView!
            
            /* Load Game scene */
            let scene = GameScene(fileNamed:"GameScene") as GameScene!
            
            /* Ensure correct aspect mode */
            scene.scaleMode = .AspectFill
            
            /* Restart game scene */
            skView.presentScene(scene)
            
        }
        buttonRestart.state = .Hidden
        scoreLabel.text = String(points)

        
    }
    
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        
        /* Disable touch if game state is not active */
        if gameState != .Active { return }
        
        hero.physicsBody?.velocity = CGVectorMake(0, 0)
        
        /* Called when a touch begins */
        
        hero.physicsBody?.applyImpulse(CGVectorMake(0, 300))
        
        //hero rotation tilt and reset of touch timer
        hero.physicsBody?.applyAngularImpulse(1)
        sinceTouch = 0
        
        //fap sound
        let flapSFX = SKAction.playSoundFileNamed("sfx_flap", waitForCompletion: false)
        self.runAction(flapSFX)
    }
    
    override func update(currentTime: CFTimeInterval) {
        
        /* Skip game update if game no longer active */
        if gameState != .Active { return }
        
        //bunny max speed
        let velocityY = hero.physicsBody?.velocity.dy ?? 0
        
        if velocityY > 400 {
            hero.physicsBody?.velocity.dy = 400
        }
        hero.physicsBody?.velocity.dx = 0
        
        //applying falling rotation
        if sinceTouch > 0.1 {
            let impulse = -20000 * fixedDelta
            hero.physicsBody?.applyAngularImpulse(CGFloat(impulse))
        }
        //applying clamp rotation
        hero.zRotation.clamp(CGFloat(-20).degreesToRadians(), CGFloat(30).degreesToRadians())
        hero.physicsBody?.angularVelocity.clamp(-2,2)
        
        sinceTouch += fixedDelta
        
        scrollWorld()
        updateObstacles()
        spawnTimer+=fixedDelta
    }
    
    func scrollWorld(){
        //world scroll
        scrollLayer.position.x -= scrollSpeed * CGFloat(fixedDelta)
        
        //obstacle scroll
        obstacleLayer = self.childNodeWithName("obstacleLayer")
        
        //loop scroll layer nodes
        for ground in scrollLayer.children as! [SKSpriteNode] {
            //get ground node position, convert node position to scene space
            let groundPosition = scrollLayer.convertPoint(ground.position, toNode: self)
            
            //check ground position has left scene
            if groundPosition.x <= -ground.size.width/2{
                //reposition ground to second starting position
                let newPosition = CGPointMake( (self.size.width / 2 ) + ground.size.width, groundPosition.y)
                //convert new node position back to scroll layer space
                ground.position = self.convertPoint(newPosition, toNode: scrollLayer)
                
            }
            
            
        }
    }
    func updateObstacles() {
        /* Update Obstacles */
        
        obstacleLayer.position.x -= scrollSpeed * CGFloat(fixedDelta)
        
        /* Loop through obstacle layer nodes */
        for obstacle in obstacleLayer.children as! [SKReferenceNode] {
            
            /* Get obstacle node position, convert node position to scene space */
            let obstaclePosition = obstacleLayer.convertPoint(obstacle.position, toNode: self)
            
            /* Check if obstacle has left the scene */
            if obstaclePosition.x <= 0 {
                
                /* Remove obstacle node from obstacle layer */
                obstacle.removeFromParent()
            }
            
        }
        /* Time to add a new obstacle? */
        if spawnTimer >= 1.5 {
            
            /* Create a new obstacle reference object using our obstacle resource */
            let resourcePath = NSBundle.mainBundle().pathForResource("Obstacle", ofType: "sks")
            let newObstacle = SKReferenceNode (URL: NSURL (fileURLWithPath: resourcePath!))
            obstacleLayer.addChild(newObstacle)
            
            /* Generate new obstacle position, start just outside screen and with a random y value */
            let randomPosition = CGPointMake(352, CGFloat.random(min: 234, max: 382))
            
            /* Convert new node position back to obstacle layer space */
            newObstacle.position = self.convertPoint(randomPosition, toNode: obstacleLayer)
            
            // Reset spawn timer
            spawnTimer = 0
        }
    }
    
    func didBeginContact(contact: SKPhysicsContact) {
        
        /* Get references to bodies involved in collision */
        let contactA:SKPhysicsBody = contact.bodyA
        let contactB:SKPhysicsBody = contact.bodyB
        
        /* Get references to the physics body parent nodes */
        let nodeA = contactA.node!
        let nodeB = contactB.node!
        
        /* Did our hero pass through the 'goal'? */
        if nodeA.name == "goal" || nodeB.name == "goal" {
            
            /* Increment points */
            points += 1
            
            /* Update score label */
            scoreLabel.text = String(points)
            
            /* We can return now */
            return
        }
        
        /* Ensure only called while game running */
        if gameState != .Active { return }
        
        /* Hero touches anything, game over */
        
        /* Change game state to game over */
        gameState = .GameOver
        
        /* Stop any new angular velocity being applied */
        hero.physicsBody?.allowsRotation = false
        
        /* Reset angular velocity */
        hero.physicsBody?.angularVelocity = 0
        
        /* Stop hero flapping animation */
        hero.removeAllActions()
        
        /* Show restart button */
        buttonRestart.state = .Active
        
        /* Create our hero death action */
        let heroDeath = SKAction.runBlock({
            
            /* Put our hero face down in the dirt */
            self.hero.zRotation = CGFloat(-90).degreesToRadians()
            /* Stop hero from colliding with anything else */
            self.hero.physicsBody?.collisionBitMask = 0
        })
        
        /* Run action */
        hero.runAction(heroDeath)
        
        /* Load the shake action resource */
        let shakeScene:SKAction = SKAction.init(named: "Shake")!
        
        /* Loop through all nodes  */
        for node in self.children {
            
            /* Apply effect each ground node */
            node.runAction(shakeScene)
        }
    }
}
