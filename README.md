In the first Terminal: 
run:
     *export key_path=~/Dektop/Aseel.pem
     *./home/Aseel/polybot_infra/bastion_connect.sh 51.21.22.216 10.0.1.29
now we connected to yolo from bastion
then run:
     *cd YoloService
     *source .venv/bin/activate
     python app.py
     
Then in another terminal:
run:
     *export key_path=~/Dektop/Aseel.pem
     *./home/Aseel/polybot_infra/bastion_connect.sh 51.21.22.216 10.0.0.186
     cd polybot
     source .venv/bin/activate
     ./polybot/run_polybot.sh
     
