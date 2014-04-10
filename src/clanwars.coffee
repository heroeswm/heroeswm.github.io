keys =
	LEFT: 37
	RIGHT: 39
	UP: 38
	DOWN: 40

mission = """
На Империю напал неизвестный враг! Вы попробовали подсчитать общее количество войск, но сбились со счёта на 13-й сотне. Вам требуется разбить их всех до одного и опровергнуть известное высказывание "всё будет зелёным". Для управления вашими войсками используйте клавиши курсора.
"""

map = """
.
     ZZZ ZZZ ZZZ  ZZ ZZZ Z Z  ZZ
       Z Z   Z Z Z    Z  Z Z Z
      Z  ZZZ ZZ  ZZZ  Z  Z Z  Z
     Z   Z   Z Z Z Z  Z  Z Z   Z
     ZZZ ZZZ Z Z  ZZ ZZZ  Z  ZZ

              ZZZZ     ZZ
             ZZ       ZZ
             ZZZ  ZZ ZZ
             ZZ  ZZZZZ
             ZZ ZZZZZ
             ZZ ZZZZZZ
             ZZ ZZZZZZ
             ZZZZZZZZ
             ZZ  ZZZZ
              ZZ
               ZZZZ
"""

start_game_banner = (div, callback) ->
	div.show().html('<div>'+mission+'</div><a class="btn clanwars-start-btn">start</a>')
	div.find('.clanwars-start-btn').click(->
		div.html('').hide()
		callback()
	)

finish_game_banner = (div, callback) ->
	div.show().html('<div>Finished</div>')
	div.find('.clanwars-finish-btn').click(->
		div.html('').hide()
		callback()
	)

class World
	constructor: (context) ->
		gravity = new b2Vec2(0, 2)
		doSleep = true
		@world = new b2World(gravity, doSleep)
		@createBox(0, 300, 10, 600)
		@createBox(800, 300, 10, 600)
		@topbox = @createBox(400, 0, 800, 10)

	step: ->
		@world.Step.apply(@world, arguments)

	createBox: (x, y, width, height, options = {}) ->
		fixDef = new b2FixtureDef
		fixDef.density = options.density ? 1.0
		fixDef.friction = options.friction ? 0.5
		fixDef.restitution = options.restitution ? 1

		bodyDef = new b2BodyDef
		bodyDef.type = if options.fixed? and !options.fixed then b2Body.b2_dynamicBody else b2Body.b2_staticBody
		fixDef.shape = new b2PolygonShape
		fixDef.shape.SetAsBox(width/30, height/30)
		bodyDef.position.Set(x/30, y/30)
		body = @world.CreateBody(bodyDef)
		body.CreateFixture(fixDef)
		body.SetUserData(options.userdata)
		body

	createBall: (x, y, options = {}) ->
		fixDef = new b2FixtureDef
		fixDef.density = 1.0
		fixDef.friction = 1
		fixDef.restitution = 1

		bodyDef = new b2BodyDef
		bodyDef.type = b2Body.b2_dynamicBody
		fixDef.shape = new b2CircleShape(7.5/30)
		bodyDef.position.Set(x/30, y/30)
		body = @world.CreateBody(bodyDef)
		body.CreateFixture(fixDef)
		body.SetUserData(options.userdata)
		body.SetBullet(yes)
		body

	checkFinish: (arg) ->
		b = @world.m_bodyList
		while b
			if b?.GetUserData()?.isClan
				return no
			b = b.m_next
		#return yes
		@finished = yes

	draw: (context) ->
#		debugDraw = new b2DebugDraw()
#		debugDraw.SetSprite(context)
#		debugDraw.SetLineThickness(1.0)
#		debugDraw.SetDrawScale(30)
#		debugDraw.SetFlags(b2DebugDraw.e_shapeBit | b2DebugDraw.e_jointBit)
#		@world.SetDebugDraw(debugDraw)
#		@world.DrawDebugData()

		b = @world.m_bodyList
		while b
			if b?.GetUserData()?.draw?
				b.GetUserData().draw(context)
			b = b.m_next

class Sprite
	constructor: (@ctx, @img, @x, @y, @w, @h, @clips) ->
		@currclip = 0

	draw: (ctx, x, y, rot) ->
		x *= 30
		y *= 30
		ctx.translate(x, y)
		ctx.rotate(rot)
		ctx.drawImage(@img, @x+@currclip*@w, @y, @w, @h, -@w/2, -@h/2, @w, @h)
		ctx.rotate(-rot)
		ctx.translate(-x, -y)
		if @animate and @clips
			@currclip = ~~((Date.now() - @begin)/100)
			if @currclip >= @clips
				@animate = false
				@currclip = 0
		else if @clips
			@animate = 1 if Math.random() > 0.999
			@begin = Date.now()

class Reflector
	constructor: (@world, ctx, img, @cols, @rows) ->
		@sprite = new Sprite(ctx, img, 0, 0, 113, 20)
		@pos = (@cols-4)/2*80
		@phys = @world.createBox(400, 575, 113/2, 20/2, {fixed:no, friction:1, userdata: @, restitution:0.88})
		@center = @world.createBox(400, 575, 5, 5, {fixed:no, friction:1, density:400})
		@mass = @phys.GetMass() + @center.GetMass()
		@center.SetLinearDamping(3)

		pjd = new b2RevoluteJointDef()
		pjd.enableLimit = true
		pjd.lowerAngle = -0.1
		pjd.upperAngle = 0.1
		pjd.Initialize(@center, @phys, @center.GetWorldCenter())
#		pjd.axis.Set(1, 0)
		@world.world.CreateJoint(pjd)

		pjd = new b2PrismaticJointDef()
		pjd.Initialize(@center, @world.topbox, @center.GetWorldCenter(), new b2Vec2(1.0, 0.0))
#		pjd.axis.Set(1, 0)
		@world.world.CreateJoint(pjd)
#		@phys.ApplyImpulse(new b2Vec2(+100000.0, 0.0), @phys.GetLocalCenter())

	draw: (ctx) ->
		pos = @phys.GetWorldCenter()
		rot = @phys.GetAngle()
		@sprite.draw(ctx, pos.x, pos.y, rot)

	left: ->
		@move(-1)

	right: ->
		@move(1)

	move: (dir) ->
		linear = @phys.GetLinearVelocity()
#		console.log(linear.x)
#		linear.x = 0 if linear.x>0
#		console.log(linear.x)
#		@phys.SetLinearVelocity(linear)
		pos = @phys.GetWorldCenter()
		return if dir == -1 && pos.x < (113/3*2)/30
		return if dir == 1 && pos.x > (800-113/3*2)/30
		@phys.ApplyImpulse(new b2Vec2(@mass * -linear.x, 0), {x:pos.x, y:pos.y})
		@phys.ApplyImpulse(new b2Vec2(@mass * dir * 12, @mass * 0.001), {x:pos.x-1000/30*dir, y:pos.y})
		@sync()
#		@pos -= time/50
#		@pos = 0 if @pos < 0

	up: (time) ->
		dir = if @phys.GetAngle() > 0 then -1 else 1
		pos = @phys.GetWorldCenter()
		@phys.ApplyImpulse(new b2Vec2(0, @mass*0.02), {x:pos.x+1000/30*dir, y:pos.y})

	down: (time) ->
		pos = @phys.GetWorldCenter()
		linear = @phys.GetLinearVelocity()
		@phys.ApplyImpulse(new b2Vec2(@mass * -linear.x, 0), {x:pos.x, y:pos.y})
#		ball = @ball.phys
##		pos = @phys.GetWorldCenter()
#		linear = @phys.GetLinearVelocity()
#		ball.ApplyImpulse(new b2Vec2(ball.GetMass() * 9 * -linear.x, 0), {x:pos.x, y:pos.y})
#		ball.ApplyImpulse(new b2Vec2(0, ball.GetMass()*-2), ball.GetWorldCenter())
#		pos = @phys.GetLocalCenter()
#		@phys.ApplyForce(new b2Vec2(0, +2000000), {x:pos.x, y:pos.y})
#		@sync()
#		@pos += time/50
#		@pos = @cols-4 if @pos > @cols-4

	ball_hit: (ball) ->
#		ball = ball.phys
#		pos = @phys.GetWorldCenter()
#		linear = @phys.GetLinearVelocity()
#		ball.ApplyImpulse(new b2Vec2(ball.GetMass() * 9 * -linear.x, 0), {x:pos.x, y:pos.y})
#		ball.ApplyImpulse(new b2Vec2(0, ball.GetMass()*-1, 0), ball.GetWorldCenter())
#		vel = ball.phys.GetLinearVelocity()
#		sum = Math.sqrt(vel.x*vel.x+vel.y*vel.y)
#		vel.x *= 1.1
#		vel.y *= 1.1
#		ball.phys.SetLinearVelocity(vel)
		###
		do (ball) ->
			setTimeout ->
				phys = ball.phys
				curvel = phys.GetLinearVelocity()
				console.log(curvel)
				curspeed = curvel.Normalize()
				velChange = 1000 - curspeed
				impulse = phys.GetMass() * velChange
				console.log(impulse)
				curvel.x *= impulse
				curvel.y *= impulse
				phys.ApplyImpulse(curvel, phys.GetWorldCenter())
			, 1000
###
	sync: ->
		###
		pos = @phys.GetLocalCenter()
		pos.y = 560
		rot = @phys.GetRotation()
		rot -= Math.PI if rot > Math.PI/2
		rot += Math.PI if rot < -Math.PI/2
		rot = 0.1 if rot > 0.1
		rot = -0.1 if rot < -0.1
		@phys.SetCenterPosition(pos, rot)
		linear = @phys.GetLinearVelocity()
		if Math.abs(linear.x) > 300
			linear.x = if linear.x > 0 then 300 else -300
			@phys.SetLinearVelocity(linear)
			###

class Ball
	constructor: (@world, ctx, img, @cols, @rows) ->
		@sprite = new Sprite(ctx, img, 0, 30, 15, 15)
		@x = (@cols-2/3)/2
		@y = @rows-2+1/3
		@phys = @world.createBall(400, 550, {userdata:@})
		@phys.ApplyImpulse(new b2Vec2(0, @phys.GetMass() * 9), @phys.GetWorldCenter())
#		@phys.ApplyForce(new b2Vec2(0, @phys.GetMass() * -10), @phys.GetWorldCenter())

	start_left: ->
		@a = Math.atan2(-Math.random()*0.2-0.9, -1) if !@a?

	start_right: ->
		@a = Math.atan2(-Math.random()*0.2-0.9, 1) if !@a?

	move: (time) ->
		return unless @a?
		@x += Math.cos(@a) * time/100
		@y += Math.sin(@a) * time/100

	draw: (ctx) ->
		pos = @phys.GetWorldCenter()
		if pos.y*30 > 1000
			@respawn()

		rot = @phys.GetAngle()
		@sprite.draw(ctx, pos.x, pos.y, rot)

		unless @phys.IsAwake()
			@respawn()

	respawn: ->
		@world.world.DestroyBody(@phys)
		rpos = @game.reflector.phys.GetWorldCenter()
		@phys = @world.createBall(rpos.x*30, 550, {userdata:@})
		@game.fails++

	sync: ->
		item = @phys.GetContactList()
		while item
			hit = item.other.GetUserData()?.ball_hit
			hit.call(item.other.GetUserData(), @) if hit?
			item = item.m_next

class Clan
	constructor: (@world, ctx, img, @x, @y) ->
		@isClan = yes
		@num = ~~(Math.random()*9)
		if @num == 8
			@altsprite = new Sprite(ctx, img, 0, 45+9*16, 20, 16)
		@sprite = new Sprite(ctx, img, 0, 45+@num*16, 20, 16, 9)
		@x = @x*20
		@y = @y*20
#		@x = ~~(Math.random()*(@cols-2)+1)*20
#		@y = ~~(Math.random()*(@rows-2)+1)*15
		@phys = @world.createBox(@x, @y, 20/2, 15/2, {userdata: @})

	ball_hit: ->
		return if @hit?
		@hit = yes
		@world.world.DestroyBody(@phys)
		@phys = @world.createBox(@x, @y, 20/2, 15/2, {fixed: no, userdata:@})
		if @num == 8
			@sprite = @altsprite

	draw: (ctx) ->
		pos = @phys.GetWorldCenter()
		if pos.y*30 > 800
			@world.world.DestroyBody(@phys)
			@world.checkFinish()
		else
			rot = @phys.GetAngle()
			@sprite.draw(ctx, pos.x, pos.y, rot)

class Game
	constructor: (resources) ->
		@canvas = $('canvas#clanwars')
		@canvas_bg = $('canvas#clanwars_bg')
		@ctx = @canvas[0].getContext('2d')
		@ctx_bg = @canvas_bg[0].getContext('2d')
		@world = new World(@ctx)
		@load(resources, @onload.bind(@))
		@pressed = {}
		@time = 0
		@fails = 0

	clear: ->
		@ctx.canvas.width = @ctx.canvas.width

	load: (resources, cb) ->
		@ctx.canvas.width = @ctx_bg.canvas.width = 800
		@ctx.canvas.height = @ctx_bg.canvas.height = 600
		@cols = @ctx.canvas.width/20
		@rows = @ctx.canvas.height/15
		count = 0
		interval = setInterval(=>
			@clear()
			@ctx.font = "30px cursive"
			points = ('.' for i in [0...count%4]).join('')
			@ctx.fillText("Loading"+points, 30, 50)
			count++
		, 500)

		sprites = new Image()
		sprites.onload = =>
			@draw_bg(sprites)
			clearInterval(interval)
			cb()
		sprites.src = 'clanwars.png'
		@reflector = new Reflector(@world, @ctx, sprites, @cols, @rows)
		@ball = new Ball(@world, @ctx, sprites, @cols, @rows)
		@reflector.ball = @ball
		@ball.game = @

		clans = []
		for str,x in map.split("\n")
			for item,y in str when item == 'Z'
				clans.push(new Clan(@world, @ctx, sprites, y+2, x))

		@canvas_bg.css('visibility', 'visible')
		@canvas.css('visibility', 'visible')

	tick: ->
		if @world.finished
			return @finish(@time*2, @fails)
		@clear()
		currTime = Date.now()
		time = currTime - @prevTick
		@prevTick = currTime
		if @pressed.left
			@reflector.left(time)
			@ball.start_left()
		if @pressed.right
			@reflector.right(time)
			@ball.start_right()
		if @pressed.up
			@reflector.up(time)
		if @pressed.down
			@reflector.down(time)
		#@ball.move(time)
		#@reflector.draw()
		#@ball.draw()
		stepping = false
		timeStep = 1/60
		@time += timeStep
		@world.step(timeStep, 1, 1)
		@reflector.sync()
		@ball.sync()
		@world.draw(@ctx)
		@ctx_bg.clearRect(6, 6, 200, 200)
		@ctx_bg.fillText("Time: "+~~(@time*2), 8, 16)
		@ctx_bg.fillText("Fails: "+@fails, 8, 28)

		@pressed = {}
		requestAnimFrame =>
			@tick()

	draw_bg: (img) ->
		ctx = @ctx_bg
		offx = 11
		offy = 206
		w = 118
		h = 11

		cx = 0
		while cx < 800
			ctx.drawImage(img, offx, offy, w-h, h, cx, 0, w-h, h/2)
			cx += w-h

		ctx.rotate(Math.PI/2)
		ctx.drawImage(img, 0, offy, h, h, 0, -11/2, h, h/2)
		ctx.drawImage(img, 0, offy, h, h, 0, -800, h, h/2)
		cx = 11/2
		while cx < 600
			ctx.drawImage(img, offx, offy, w-h, h, cx, -11/2, w-h, h/2)
			ctx.drawImage(img, offx, offy, w-h, h, cx, -800, w-h, h/2)
			cx += w-h
		ctx.rotate(-Math.PI/2)

	onload: ->
		@prevTick = Date.now()
		@started = yes
		@tick()

	keypress: (key) ->
		return unless @started?
		switch key
			when keys.LEFT
				@pressed.left = yes
			when keys.RIGHT
				@pressed.right = yes
			when keys.UP
				@pressed.up = yes
			when keys.DOWN
				@pressed.down = yes

define 'clanwars', ->
	canvas = $('canvas#clanwars')
	canvas.before('<canvas id="clanwars_bg" width=800 height=600></canvas>')
	canvas_bg = $('canvas#clanwars_bg')
	canvas_bg.css('background-image', 'url(clanwars-bg.jpeg)')
	canvas_bg.css('background-size', '100% 100%')
	canvas.offset(canvas_bg.offset())
	dialogs = $('#clanwars_dialogs')
	dialogs.offset(canvas_bg.offset())
	dialogs.width(800).height(600)

	start_game_banner(dialogs, ->
		window.b2AABB = Box2D.Collision.b2AABB
		window.b2Vec2 = Box2D.Common.Math.b2Vec2
		window.b2World = Box2D.Dynamics.b2World
		window.b2BodyDef = Box2D.Dynamics.b2BodyDef
		window.b2Body = Box2D.Dynamics.b2Body
		window.b2Fixture = Box2D.Dynamics.b2Fixture
		window.b2FixtureDef = Box2D.Dynamics.b2FixtureDef
		window.b2PolygonShape = Box2D.Collision.Shapes.b2PolygonShape
		window.b2CircleShape = Box2D.Collision.Shapes.b2CircleShape
		window.b2DebugDraw = Box2D.Dynamics.b2DebugDraw
		for k,o of Box2D.Dynamics.Joints
			window[k] = o

		game = new Game()
		$(document).keydown((e)->
			game.keypress(e.keyCode)
		)
		game.finish = (tick, fails) ->
			finish_game_banner(dialogs, ->
				game.clear()
				statistics_banner(dialogs, {}, ->
				)
			)
	)

# http://paulirish.com/2011/requestanimationframe-for-smart-animating/
window.requestAnimFrame = do ->
  return  window.requestAnimationFrame       ||
          window.webkitRequestAnimationFrame ||
          window.mozRequestAnimationFrame    ||
          window.oRequestAnimationFrame      ||
          window.msRequestAnimationFrame     ||
          (callback, element) ->
            window.setTimeout(callback, 1000 / 60)

